module diskuto.web;

import diskuto.backend : CommentStatus, DiskutoBackend, StoredComment;
import diskuto.userstore : DiskutoUserStore, StoredUser;
import diskuto.settings : DiskutoSettings;

import vibe.http.router : URLRouter;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.web.web;

import std.exception : enforce;
import std.typecons : Nullable;


DiskutoWeb registerDiskutoWeb(URLRouter router, DiskutoBackend backend)
{
	auto settings = new DiskutoSettings;
	settings.backend = backend;
	return registerDiskutoWeb(router, settings);
}

DiskutoWeb registerDiskutoWeb(URLRouter router, DiskutoSettings settings)
{
	auto wi = new DiskutoWebInterface(settings);
	router.registerWebInterface(wi);
	return DiskutoWeb(wi);
}

struct DiskutoWeb {
	private DiskutoWebInterface m_web;

	package @property DiskutoBackend backend() { return m_web.m_settings.backend; }

	@property string uid()
	{
		assert(m_web.m_userID.length, "No UID, setupRequest() not called?");
		return m_web.m_userID;
	}

	@property DiskutoSettings settings()
	{
		return m_web.m_settings;
	}

	void setupRequest()
	{
		if (!m_web.m_userID.length) {
			import std.format : format;
			import std.random : uniform;
			// TODO: Use a cryptographic RNG from vibe.crypto.random. Not _really_ needed, but best practice anyway.
			m_web.m_userID = format("%016X%016X", uniform!ulong(), uniform!ulong());
		}
	}
}

@path("diskuto")
private final class DiskutoWebInterface {
	import antispam.antispam;
	import diskuto.internal.webutils : SessionVars, User;

	private {
		DiskutoSettings m_settings;
		AntispamState m_antispam;
		SessionVar!(string, SessionVars.userID) m_userID;
		SessionVar!(string, SessionVars.name) m_sessionName;
		SessionVar!(string, SessionVars.email) m_sessionEmail;
		SessionVar!(string, SessionVars.website) m_sessionWebsite;
		SessionVar!(string, SessionVars.lastPost) m_sessionLastPost;
	}

	this(DiskutoSettings settings)
	{
		import vibe.core.file : readFileUTF8;
		import vibe.data.json : parseJsonString;

		m_settings = settings;
		m_antispam = new AntispamState;
		m_antispam.loadConfig(parseJsonString(readFileUTF8("antispam.json")));
	}

	@errorDisplay!sendWebError
	void post(HTTPServerRequest req, string name, string email, string website, string topic, string reply_to, string text)
	{
		doPost(req, getUser(req), name, email, website, topic, reply_to, text);
		redirectBack(req);
	}

	@errorDisplay!sendWebError
	void up(HTTPServerRequest req, string id)
	{
		auto usr = getUser(req);
		m_settings.backend.upvote(id, usr.id);
		redirectBack(req);
	}

	@errorDisplay!sendWebError
	void down(HTTPServerRequest req, string id)
	{
		auto usr = getUser(req);
		m_settings.backend.downvote(id, usr.id);
		redirectBack(req);
	}

	@errorDisplay!sendJsonError
	void postPost(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto data = req.json;
		auto comment = doPost(req, getUser(req),
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
		auto usr = getUser(req);
		auto data = req.json;

		enforceAuthorizedToEdit(req, data["id"].get!string, usr);

		m_settings.backend.editComment(data["id"].get!string, data["text"].get!string);

		static struct Reply {
			bool success = true;
			string rendered;
		}

		Reply reply;
		reply.rendered = renderCommentContents(data["text"].get!string);
		res.writeJsonBody(reply);
	}

	@errorDisplay!sendJsonError
	void postDelete(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto usr = getUser(req);
		auto data = req.json;

		enforceAuthorizedToEdit(req, data["id"].get!string, usr);

		m_settings.backend.deleteComment(data["id"].get!string);

		static struct Reply { bool success = true; }
		res.writeJsonBody(Reply.init);
	}

	@errorDisplay!sendJsonError
	void vote(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto usr = getUser(req);
		auto cmd = req.json;
		auto dir = cmd["dir"].get!int;
		auto id = cmd["id"].get!string;
		if (dir > 0) m_settings.backend.upvote(id, usr.id);
		else if (dir < 0) m_settings.backend.downvote(id, usr.id);
		res.writeJsonBody(["success": true]);
	}

	@errorDisplay!sendJsonError
	void getTopic(HTTPServerResponse res, string topic)
	{
		static struct S { bool success; StoredComment[] comments; }
		res.writeJsonBody(S(true, m_settings.backend.getCommentsForTopic(topic)));
	}

	@errorDisplay!sendJsonError
	void getLatestComments(HTTPServerResponse res)
	{
		static struct S { bool success; StoredComment[] comments; }
		res.writeJsonBody(S(true, m_settings.backend.getLatestComments()));
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

		m_sessionName = name;
		m_sessionEmail = email;
		m_sessionWebsite = website;

		StoredComment comment;
		comment.userID = user.id;
		comment.topic = topic;
		comment.replyTo = reply_to;
		comment.name = name;
		comment.email = email;
		comment.website = website;
		comment.text = text;
		comment.time = Clock.currTime(UTC());
		comment.id = m_settings.backend.postComment(comment);

		bool is_spam_async = false;

		checkSpamState(req, name, email, website, text, {
			if (comment.id.length)
				m_settings.backend.setCommentStatus(comment.id, CommentStatus.spam);
			is_spam_async = true;
		});

		m_sessionLastPost = comment.id;

		if (is_spam_async)
			m_settings.backend.setCommentStatus(comment.id, CommentStatus.spam);
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

	private User getUser(HTTPServerRequest req)
	{
		auto usr = m_settings.userStore.getLoggedInUser(req);
		if (!usr.isNull)
			return User(usr, true);
		enforce(m_userID.length, "Unauthorized request. Please make sure that your browser supports cookies.");
		User ret;
		ret.registered = false;
		ret.id = m_userID;
		ret.name = m_sessionName;
		ret.email = m_sessionEmail;
		ret.website = m_sessionWebsite;
		return ret;
	}

	private string renderComment(HTTPServerRequest req, StoredComment scomment)
	{
		import std.datetime : Clock, UTC;

		import std.array : appender;
		import diet.html : compileHTMLDietFile;
		import diskuto.internal.webutils : Comment, getCommentsContext;

		auto c = Comment(scomment, Clock.currTime(UTC()));
		auto comment = &c;
		auto web = DiskutoWeb(this);
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

	private void checkSpamState(HTTPServerRequest req, string name, string email, string website, string text, void delegate() @safe revoke)
	{
		import std.algorithm.comparison : among;
		import std.algorithm.iteration : map, splitter;
		import std.array : array;
		import std.string : strip;

		AntispamMessage msg;
		msg.headers["From"] = name.length ? email.length ? name ~ " <" ~ email ~ ">" : name : email;
		msg.headers["Subject"] = website; // TODO: maybe use a different header
		msg.message = cast(const(ubyte)[])text;

		if( auto pp = "X-Forwarded-For" in req.headers )
			msg.peerAddress = (*pp).splitter(',').map!strip.array ~ req.peer;
		else msg.peerAddress = [req.peer];

		m_antispam.filterMessage!(
			(status) {
				if (status.among(SpamAction.revoke, SpamAction.block))
					throw new Exception("Your message has been deemed abusive!");
			},
			(async_status) {
				if (async_status.among!(SpamAction.revoke, SpamAction.block))
					revoke();
			}
		)(msg);
	}

	private void enforceAuthorizedToEdit(HTTPServerRequest req, StoredComment.ID comment, in ref StoredUser user)
	{
		import std.datetime : Clock, UTC;
		import core.time : minutes;

		if (!user.isModerator) {
			auto c = m_settings.backend.getComment(comment);
			auto now = Clock.currTime(UTC());
			enforce(c.userID == user.id, "Not allowed to modify comment.");
			enforce(now - c.time < m_settings.hardEditTimeLimit, "Comment cannot be modified anymore.");
		}
	}
}

private void writeSuccess(HTTPServerResponse res)
{
	static struct S { bool success; }
	res.writeJsonBody(S(true));
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
