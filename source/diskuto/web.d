module diskuto.web;

import diskuto.commentstore : DiskutoCommentStore, StoredComment, VoteDirection;
import diskuto.userstore : DiskutoUserStore, StoredUser;
import diskuto.settings : DiskutoSettings;
import diskuto.internal.webutils : SessionVars, User;

import vibe.http.router : URLRouter;
import vibe.http.fileserver : HTTPFileServerSettings, serveStaticFiles;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.web.web;

import antispam.antispam : AntispamState, AntispamMessage, SpamAction, filterMessage;

import std.exception : enforce;
import std.typecons : Nullable;


DiskutoWeb registerDiskutoWeb(URLRouter router, DiskutoCommentStore comment_store)
{
	auto settings = new DiskutoSettings;
	settings.commentStore = comment_store;
	return registerDiskutoWeb(router, settings);
}

DiskutoWeb registerDiskutoWeb(URLRouter router, DiskutoSettings settings)
{
	auto antispam = new AntispamState;
	antispam.loadConfig(settings.antispam);

	auto wsettings = new WebInterfaceSettings;
	wsettings.urlPrefix = "/diskuto";
	router.registerWebInterface(new DiskutoWebInterface(settings, antispam), wsettings);
	router.registerWebInterface(new DiskutoWebManagementInterface(settings, antispam), wsettings);

	auto fsettings = new HTTPFileServerSettings;
	fsettings.serverPathPrefix = "/diskuto/";
	router.get("/diskuto/*", serveStaticFiles(settings.resourcePath, fsettings));

	return DiskutoWeb(settings);
}

struct DiskutoWeb {
	private {
		DiskutoSettings m_settings;
		SessionVar!(string, SessionVars.userID) m_userID;
	}

	this(DiskutoSettings settings)
	{
		m_settings = settings;
	}

	package @property DiskutoCommentStore commentStore() { return m_settings.commentStore; }

	string getBasePath(string root_path = "/")
	{
		return root_path ~ "diskuto";
	}

	@property string uid()
	{
		assert(m_userID.length, "No UID, setupRequest() not called?");
		return m_userID;
	}

	@property DiskutoSettings settings()
	{
		return m_settings;
	}

	void setupRequest(HTTPServerRequest req, HTTPServerResponse res)
	{
		if (!req.session)
			req.session = res.startSession();

		if (!req.session.get(SessionVars.userID, "").length) {
			import std.format : format;
			import std.random : uniform;
			// TODO: Use a cryptographic RNG from vibe.crypto.random. Not _really_ needed, but best practice anyway.
			req.session.set(SessionVars.userID, format("%016X%016X", uniform!ulong(), uniform!ulong()));
		}
	}

	void setupRequest()
	{
		if (!m_userID.length) {
			import std.format : format;
			import std.random : uniform;
			// TODO: Use a cryptographic RNG from vibe.crypto.random. Not _really_ needed, but best practice anyway.
			m_userID = format("%016X%016X", uniform!ulong(), uniform!ulong());
		}
	}

	void generateInclude(R)(ref R dst, HTTPServerRequest req, string topic)
	{
		import diet.html : compileHTMLDietFile;
		DiskutoWeb web = this;
		string base = web.getBasePath(req.rootDir);
		dst.compileHTMLDietFile!("diskuto.part.comments.dt", req, web, base, topic);
	}
}

@path("manage")
private final class DiskutoWebManagementInterface {
	private {
		DiskutoSettings m_settings;
		AntispamState m_antispam;
		bool m_reclassifyInProgress = false;
		string m_reclassifyError = null;
	}

	this(DiskutoSettings settings, AntispamState antispam)
	{
		m_settings = settings;
		m_antispam = antispam;
	}

	void get(HTTPServerRequest req, string _error = null)
	{
		auto usr = getUser(req, m_settings, null);
		enforce(usr.role >= StoredUser.Role.moderator,
			"Not authorized to manage comments.");

		auto web = DiskutoWeb(m_settings);
		bool reclassifyInProgress = m_reclassifyInProgress;
		string base = web.getBasePath(req.rootDir);
		string error = _error.length ? _error : m_reclassifyError;
		render!("diskuto.manage.dt", reclassifyInProgress, base, error);
	}

	@errorDisplay!get
	void reclassifySpam(HTTPServerRequest req)
	{
		import vibe.core.core : runTask, yield;

		auto usr = getUser(req, m_settings, null);
		enforce(usr.role >= StoredUser.Role.moderator,
			"Not authorized to manage comments.");

		enforce(!m_reclassifyInProgress, "Spam reclassification is still in progress.");
		m_reclassifyInProgress = true;
		scope (exit) m_reclassifyInProgress = false;
		m_reclassifyError = null;

		runTask({
			try {
				m_antispam.resetClassification();
				m_settings.commentStore.iterateAllComments((ref c) {
					AntispamMessage msg;
					c.convertToAntispam(msg, m_antispam);

					final switch (c.status) with (StoredComment.Status) {
						case active: m_antispam.classify(msg, false); break;
						case disabled: // ignore
						case awaitsModeration: // ignore
						case spam: m_antispam.classify(msg, true); break;
						case deleted: break; // ignore
					}
					yield();
				});
			} catch (Exception e) {
				m_reclassifyError = e.msg;
			}
		});

		redirect(DiskutoWeb(m_settings).getBasePath(req.rootDir)~"/manage");
	}
}

private final class DiskutoWebInterface {
	import diskuto.internal.webutils : User;

	private {
		DiskutoSettings m_settings;
		AntispamState m_antispam;
		SessionVar!(string, SessionVars.userID) m_userID;
		SessionVar!(string, SessionVars.name) m_sessionName;
		SessionVar!(string, SessionVars.email) m_sessionEmail;
		SessionVar!(string, SessionVars.website) m_sessionWebsite;
		SessionVar!(string, SessionVars.lastPost) m_sessionLastPost;
	}

	this(DiskutoSettings settings, AntispamState antispam)
	{
		m_settings = settings;
		m_antispam = antispam;
	}

	@errorDisplay!sendWebError
	void post(HTTPServerRequest req, string name, string email, string website, string topic, string reply_to, string text)
	{
		doPost(req, getUser(req, m_settings, topic), name, email, website, topic, reply_to, text);
		redirectBack(req);
	}

	@errorDisplay!sendWebError
	void up(HTTPServerRequest req, string id)
	{
		auto topic = m_settings.commentStore.getComment(id).topic; // TODO: be more efficient here!
		auto usr = getUser(req, m_settings, topic);
		m_settings.commentStore.vote(id, usr.id, 1);
		redirectBack(req);
	}

	@errorDisplay!sendWebError
	void down(HTTPServerRequest req, string id)
	{
		auto topic = m_settings.commentStore.getComment(id).topic; // TODO: be more efficient here!
		auto usr = getUser(req, m_settings, topic);
		m_settings.commentStore.vote(id, usr.id, -1);
		redirectBack(req);
	}

	@errorDisplay!sendWebError
	void getRenderTopic(HTTPServerRequest req, string topic, string base)
	{
		auto web = DiskutoWeb(m_settings);
		web.setupRequest();
		auto usr = getUser(req, m_settings, topic);
		enforce(usr.role >= StoredUser.Role.reader, "Not allowed to read topic.");
		render!("diskuto.part.comments.dt", web, base, topic);
	}

	@errorDisplay!sendJsonError
	void postPost(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto data = req.json;
		auto comment = doPost(req, getUser(req, m_settings, data["topic"].get!string),
			data["name"].get!string,
			data["email"].get!string,
			data["website"].get!string,
			data["topic"].get!string,
			data["reply_to"].get!string,
			data["text"].get!string
		);

		static struct Reply {
			bool success = true;
			string rendered;
		}

		Reply reply;
		reply.rendered = renderComment(req, comment);
		res.writeJsonBody(reply);
	}

	@errorDisplay!sendJsonError
	void edit(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto data = req.json;
		auto id = data["id"].get!string;
		auto text = data["text"].get!string;
		auto comment = m_settings.commentStore.getComment(id);
		auto usr = getUser(req, m_settings, comment.topic);

		enforceAuthorizedToEdit(req, comment, usr);
		enforce(text.length < 4096, "Message text is too long.");

		m_settings.commentStore.editComment(id, text);

		static struct Reply {
			bool success = true;
			string rendered;
		}

		Reply reply;
		reply.rendered = renderCommentContents(text);
		res.writeJsonBody(reply);
	}

	@errorDisplay!sendJsonError
	void postDelete(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto data = req.json;
		auto id = data["id"].get!string;
		auto comment = m_settings.commentStore.getComment(id);
		auto usr = getUser(req, m_settings, comment.topic);

		enforceAuthorizedToEdit(req, comment, usr);

		m_settings.commentStore.setCommentStatus(id, StoredComment.Status.deleted);

		static struct Reply { bool success = true; }
		res.writeJsonBody(Reply.init);
	}

	@errorDisplay!sendJsonError
	void postSetStatus(HTTPServerRequest req, HTTPServerResponse res)
	{
		import std.conv : to;

		auto data = req.json;
		auto id = data["id"].get!string;
		auto status = data["status"].get!string.to!(StoredComment.Status);
		auto comment = m_settings.commentStore.getComment(id);
		auto usr = getUser(req, m_settings, comment.topic);
		enforce(usr.isModerator, "Only moderators can change the comment status.");

		if (comment.status != status) {
			m_settings.commentStore.setCommentStatus(id, status);

			// reclassify spam status
			if (comment.status == StoredComment.Status.spam || status == StoredComment.Status.spam) {
				AntispamMessage msg;
				comment.convertToAntispam(msg, m_antispam);
				switch (comment.status) {
					default: break;
					case StoredComment.Status.spam: m_antispam.declassify(msg, true); break;
					case StoredComment.Status.active: m_antispam.declassify(msg, false); break;
				}
				switch (status) {
					default: break;
					case StoredComment.Status.spam: m_antispam.classify(msg, true); break;
					case StoredComment.Status.active: m_antispam.classify(msg, false); break;
				}
			}
		}

		static struct Reply { bool success = true; }
		res.writeJsonBody(Reply.init);
	}

	@errorDisplay!sendJsonError
	void vote(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto cmd = req.json;
		VoteDirection dir = cmd["dir"].get!int > 0 ? VoteDirection.up : VoteDirection.down;
		auto id = cmd["id"].get!string;
		auto topic = m_settings.commentStore.getComment(id).topic; // TODO: be more efficient here!
		auto usr = getUser(req, m_settings, topic);
		enforce(usr.role >= StoredUser.Role.member, "Not allowed to vote!");

		auto newdir = m_settings.commentStore.vote(id, usr.id, dir);
		res.writeJsonBody(["success": true, "dir": cast(int)newdir]);
	}

	@errorDisplay!sendJsonError
	void getTopic(HTTPServerRequest req, HTTPServerResponse res, string topic)
	{
		static struct S { bool success; StoredComment[] comments; }
		auto usr = getUser(req, m_settings, topic);
		enforce(usr.role >= StoredUser.Role.reader, "Not allowed to read topic.");
		res.streamComments!(del => m_settings.commentStore.iterateCommentsForTopic(topic, del));
	}

	@errorDisplay!sendJsonError
	void getLatestComments(HTTPServerRequest req, HTTPServerResponse res)
	{
		static struct S { bool success; StoredComment[] comments; }
		auto usr = getUser(req, m_settings, null);
		enforce(usr.role >= StoredUser.Role.moderator, "Only moderaters are allowed to read recent comments.");
		res.streamComments!(del => m_settings.commentStore.iterateLatestComments(del));
	}

	@noRoute
	void sendJsonError(HTTPServerResponse res, string _error)
	{
		struct E {
			bool success;
			string error;
		}
		res.writeJsonBody(E(false, _error));
	}

	@noRoute
	void sendWebError(HTTPServerRequest req, string _error)
	{
		redirectBack(req, "diskuto-error", _error);
	}

	private StoredComment doPost(HTTPServerRequest req, User user, string name, string email, string website, string topic, string reply_to, string text)
	{
		import std.datetime : Clock, UTC;

		enforce(name.length < 40, "Name is too long.");
		enforce(text.length > 0, "Missing message text.");
		enforce(text.length < 4096, "Message text is too long.");

		if (email.length > 0) {
			enforce(email.length < 80, "E-mail is too long.");
			import vibe.utils.validation : validateEmail;
			validateEmail(email);

			if (user.registered) {
				enforce(email == user.email, "Invalid e-mail address: expected "~user.email);
			} else {
				enforce(m_settings.userStore.getUserForEmail(email).isNull,
					"This e-mail address is already associated with a registered account. Please log in to use this address.");
			}
		}

		if (website.length > 0) {
			enforce(website.length < 80, "Website address is too long.");
			import std.algorithm.comparison : among;
			import vibe.inet.url : URL;
			auto url = URL.parse(website);
			enforce(url.schema.among("http", "https"), "Only http:// and https:// are allowed as website address.");
		}

		if (!user.registered) {
			m_sessionName = name;
			m_sessionEmail = email;
			m_sessionWebsite = website;
		}

		StoredComment comment;
		comment.author = user.id;
		comment.clientAddress = req.peer;
		if (auto pp = "X-Forwarded-For" in req.headers)
			comment.clientAddress = (*pp) ~ ',' ~ comment.clientAddress;
		comment.topic = topic;
		comment.replyTo = reply_to;
		comment.name = name;
		comment.email = email;
		comment.website = website;
		comment.text = text;
		comment.time = Clock.currTime(UTC());

		bool is_spam_async = false;

		checkSpamState(req, comment, {
			if (comment.id.length)
				m_settings.commentStore.setCommentStatus(comment.id, StoredComment.Status.spam);
			is_spam_async = true;
		});

		comment.id = m_settings.commentStore.postComment(comment);

		m_sessionLastPost = comment.id;

		if (is_spam_async)
			m_settings.commentStore.setCommentStatus(comment.id, StoredComment.Status.spam);
		return comment;
	}

	private void redirectBack(HTTPServerRequest req, string field = null, string value = null)
	{
		import vibe.textfilter.urlencode : urlEncode;
		import std.algorithm.searching : canFind;

		auto url = req.headers.get("Referer", "/");
		if (field.length) {
			if (url.canFind('?')) url ~= '&';
			else url ~= '?';
			url ~= field ~ "=" ~ urlEncode(value);
		}
		redirect(url);
	}

	private string renderComment(HTTPServerRequest req, StoredComment scomment)
	{
		import std.datetime : Clock, UTC;

		import std.array : appender;
		import diet.html : compileHTMLDietFile;
		import diskuto.internal.webutils : Comment, getCommentsContext;

		auto c = Comment(scomment, Clock.currTime(UTC()));
		auto comment = &c;
		auto web = DiskutoWeb(m_settings);
		auto ctx = getCommentsContext(req, web, null);
		auto usr = ctx.user;
		auto dst = appender!string();
		dst.compileHTMLDietFile!("diskuto.part.comment.dt", req, web, usr, comment);
		return dst.data;
	}

	private string renderCommentContents(string text)
	{
		import std.array : appender;
		import diet.html : compileHTMLDietFile;

		StoredComment comment;
		comment.text = text;
		auto dst = appender!string();
		dst.compileHTMLDietFile!("diskuto.inc.commentContents.dt", comment);
		return dst.data;
	}

	private void checkSpamState(HTTPServerRequest req, StoredComment comment, void delegate() @safe revoke)
	{
		import std.algorithm.comparison : among;

		AntispamMessage msg;
		comment.convertToAntispam(msg, m_antispam);

		m_antispam.filterMessage!(
			(status) {
				if (status.among(SpamAction.revoke, SpamAction.block)) {
					throw new Exception("Your message has been deemed abusive!");
				}
			},
			(async_status) {
				if (async_status.among!(SpamAction.revoke, SpamAction.block))
					revoke();
			}
		)(msg);
	}

	private void enforceAuthorizedToEdit(HTTPServerRequest req, StoredComment comment, in ref StoredUser user)
	{
		import std.datetime : Clock, UTC;
		import core.time : minutes;

		auto role = m_settings.userStore ? m_settings.userStore.getUserRole(user.id, comment.topic) : StoredUser.Role.member;
		final switch (role) with (StoredUser) {
			case Role.none, Role.reader:
				throw new Exception("You are not allowed to modify comments.");
			case Role.moderator:
				break;
			case Role.commenter, Role.member:
				auto now = Clock.currTime(UTC());
				enforce(comment.author == user.id, "Not allowed to modify comment.");
				enforce(now - comment.time < m_settings.hardEditTimeLimit, "Comment cannot be modified anymore.");
				break;
		}
	}
}

private void streamComments(alias iterator)(HTTPServerResponse res)
{
	res.contentType = "application/json; charset=UTF-8";
	res.bodyWriter.write(`{"success": true, [`);
	iterator(delegate void(ref StoredComment c) {
		import vibe.data.json : serializeToJson;
		import vibe.stream.wrapper : streamOutputRange;
		auto r = streamOutputRange(res.bodyWriter);
		(&r).serializeToJson(c);
	});
	res.bodyWriter.write(`]}`);
}

private void writeSuccess(HTTPServerResponse res)
{
	static struct S { bool success; }
	res.writeJsonBody(S(true));
}

private void convertToAntispam(in ref StoredComment comment, ref AntispamMessage msg, AntispamState antispam)
{
	import std.algorithm.iteration : map, splitter;
	import std.array : array;
	import std.string : strip;

	msg.headers["From"] = comment.name.length ? comment.email.length ? comment.name ~ " <" ~ comment.email ~ ">" : comment.name : comment.email;
	msg.headers["Subject"] = comment.website; // TODO: maybe use a different header
	msg.message = cast(const(ubyte)[])comment.text;
	msg.peerAddress = comment.clientAddress.splitter(',').map!strip.array;
}

private User getUser(HTTPServerRequest req, DiskutoSettings settings, string topic)
{
	User ret;

	if (settings.userStore) {
		auto usr = settings.userStore.getLoggedInUser(req);
		if (!usr.isNull) {
			ret.user = usr;
			ret.registered = true;
			ret.role = settings.userStore.getUserRole(usr.id, topic);
			return ret;
		}
	}

	if (req.session) {
		ret.id = req.session.get!string(SessionVars.userID);
		ret.name = req.session.get!string(SessionVars.name, null);
		ret.email = req.session.get!string(SessionVars.email, null);
		ret.website = req.session.get!string(SessionVars.website, null);
	}

	enforce(ret.id.length, "Unauthorized request. Please make sure that your browser supports cookies.");
	ret.registered = false;
	ret.role = settings.userStore ? settings.userStore.getUserRole(ret.id, topic) : StoredUser.Role.member;
	return ret;
}


/*private struct ValidURL {
	import vibe.inet.url : URL;

	private string m_value;

	private this(string value) { m_value = value; }
	@disable this();

	string toString() const pure nothrow @safe { return m_value; }
	alias toString this;

	static Nullable!ValidURL fromStringValidate(string str, string* error)
	{
		// work around disabled default construction
		Nullable!ValidURL ret = Nullable!ValidURL(ValidURL(null));
		ret.nullify();
		try ret = ValidURL(URL.parse(str).toString());
		catch (Exception e) *error = e.msg;
		return ret;
	}
}*/
