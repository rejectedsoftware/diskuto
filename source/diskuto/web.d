module diskuto.web;

import diskuto.backend : StoredComment, DiskutoBackend;

import vibe.http.router : URLRouter;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.web.web;

import std.exception : enforce;
import std.typecons : Nullable;


void registerDiskutoWeb(URLRouter router, DiskutoBackend backend)
{
	router.registerWebInterface(new DiskutoWeb(backend));
}

@path("diskuto")
private final class DiskutoWeb {
	private {
		DiskutoBackend m_backend;
		SessionVar!(string, "diskuto.userID") m_userID;
		SessionVar!(string, "diskuto.name") m_sessionName;
		SessionVar!(string, "diskuto.email") m_sessionEmail;
		SessionVar!(string, "diskuto.homepage") m_sessionHomepage;
		SessionVar!(string, "diskuto.lastPost") m_sessionLastPost;
	}

	this(DiskutoBackend backend)
	{
		m_backend = backend;
	}

	@errorDisplay!sendWebError
	void post(HTTPServerRequest req, string name, string email, string website, string topic, string reply_to, string text)
	{
		auto id = doPost(name, email, website, topic, reply_to, text);
		redirectBack(req);
	}

	@errorDisplay!sendWebError
	void up(HTTPServerRequest req, string id)
	{
		m_backend.upvote(id, getUserID());
		redirectBack(req);
	}

	@errorDisplay!sendWebError
	void down(HTTPServerRequest req, string id)
	{
		m_backend.downvote(id, getUserID());
		redirectBack(req);
	}

	@errorDisplay!sendJsonError
	void postPost(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto data = req.json;
		auto id = doPost(
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
		reply.rendered = renderComment(id);
		res.writeJsonBody(reply);
	}

	@errorDisplay!sendJsonError
	void edit(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto data = req.json;
		// FIXME: validate that user is author (+time limit) or moderator!
		m_backend.editComment(data["id"].get!string, data["text"].get!string);

		static struct Reply {
			bool success = true;
			string rendered;
		}

		Reply reply;
		reply.rendered = renderComment(data["id"].get!string);
		res.writeJsonBody(reply);
	}

	@errorDisplay!sendJsonError
	void postDelete(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto data = req.json;
		// FIXME: validate that user is author (+time limit) or moderator!
		m_backend.deleteComment(data["id"].get!string);

		static struct Reply { bool success = true; }
		res.writeJsonBody(Reply.init);
	}

	@errorDisplay!sendJsonError
	void vote(HTTPServerRequest req, HTTPServerResponse res)
	{
		auto cmd = req.json;
		auto dir = cmd["dir"].get!int;
		auto id = cmd["id"].get!string;
		if (dir > 0) m_backend.upvote(id, getUserID());
		else if (dir < 0) m_backend.downvote(id, getUserID());
		res.writeJsonBody(["success": true]);
	}

	@errorDisplay!sendJsonError
	void getTopic(HTTPServerResponse res, string topic)
	{
		static struct S { bool success; StoredComment[] comments; }
		res.writeJsonBody(S(true, m_backend.getCommentsForTopic(topic)));
	}

	@errorDisplay!sendJsonError
	void getLatestComments(HTTPServerResponse res)
	{
		static struct S { bool success; StoredComment[] comments; }
		res.writeJsonBody(S(true, m_backend.getLatestComments()));
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

	private string doPost(string name, string email, string website, string topic, string reply_to, string text)
	{
		import std.datetime : Clock, UTC;

		enforce(name.length < 40, "Name is too long.");
		enforce(text.length > 0, "Missing message text.");
		enforce(text.length < 4096, "Message text is too long.");
		if (email.length > 0) {
			import vibe.utils.validation : validateEmail;
			validateEmail(email);
		}

		if (website.length > 0) {
			import std.algorithm.comparison : among;
			import vibe.inet.url : URL;
			auto url = URL.parse(website);
			enforce(url.schema.among("http", "https"), "Only http:// and https:// are allowed as website address.");
		}

		m_sessionName = name;
		m_sessionEmail = email;
		m_sessionHomepage = website;

		StoredComment comment;
		comment.userID = getUserID();
		comment.topic = topic;
		comment.replyTo = reply_to;
		comment.name = name;
		comment.email = email;
		comment.website = website;
		comment.text = text;
		comment.time = Clock.currTime(UTC());
		auto id = m_backend.postComment(comment);
		m_sessionLastPost = id;
		return id;
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

	private string getUserID()
	{
		if (!m_userID.length) {
			import std.format : format;
			import std.random : uniform;
			m_userID = format("%016X%016X", uniform!ulong(), uniform!ulong());
		}
		return m_userID;
	}

	private string renderComment(string id)
	{
		//auto comment = m_backend.getComment(id);
		return "<p class=\"contents\">TODO!</p>";
	}
}

private void writeSuccess(HTTPServerResponse res)
{
	static struct S { bool success; }
	res.writeJsonBody(S(true));
}

private struct ValidURL {
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
}