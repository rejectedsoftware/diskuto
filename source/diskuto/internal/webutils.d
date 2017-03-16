module diskuto.internal.webutils;

import diskuto.backend : CommentStatus, DiskutoBackend, StoredComment;
import diskuto.userstore : StoredUser;
import diskuto.web : DiskutoWeb;
import vibe.http.server : HTTPServerRequest;
import std.algorithm.comparison : max;
import std.datetime : SysTime;
import core.time : Duration, msecs;


enum SessionVars {
	userID = "diskuto.userID",
	name = "diskuto.name",
	email = "diskuto.email",
	website = "diskuto.website",
	lastPost = "diskuto.lastPost"
}

struct Comment {
	StoredComment comment;
	alias comment this;

	Duration age;
	string avatarID;
	int avatarWidth;
	int avatarHeight;
	Comment*[] replies;

	this(StoredComment comment, SysTime now)
	{
		this.comment = comment;
		this.age = max(now - comment.time, 1.msecs);
		this.avatarWidth = 48;
		this.avatarHeight = 48;
		this.avatarID = comment.email.length ? comment.email : comment.author ~ "@diskuto";
	}

	bool isVisibleTo(StoredComment.UserID user)
	{
		//if (isModerator(user)) return true;
		if (comment.status == CommentStatus.deleted) return false;
		if (comment.author == user) return true;
		return comment.status == CommentStatus.active;
	}
}

struct User {
	StoredUser user;
	alias user this;
	bool registered;
}


auto getCommentsContext(HTTPServerRequest req, DiskutoWeb web, string topic)
{
	import diskuto.backend : StoredComment;
	import std.datetime : Clock, UTC;
	import std.algorithm.searching : count;
	import std.algorithm.sorting : sort;

	auto backend = web.backend;

	static struct Info {
		size_t commentCount;
		Comment*[] comments;
		User user;
	}

	SysTime now = Clock.currTime(UTC());

	Info ret;
	if (topic.length) {
		auto dbcomments = backend.getCommentsForTopic(topic);
		auto comments = new Comment[](dbcomments.length);
		size_t curidx;
		ret.commentCount = dbcomments.count!(c => c.status == CommentStatus.active);
		size_t[StoredComment.ID] map;
		foreach (c; dbcomments) {
			auto idx = curidx++;
			map[c.id] = idx;
			comments[idx] = Comment(c, now);
		}

		foreach (ref c; comments) {
			if (!c.replyTo.length) ret.comments ~= &c;
			else {
				if (auto rti = c.replyTo in map)
					comments[*rti].replies ~= &c;
			}
		}

		static double getScore(Comment* c) {
			// basic sortig based on the ratio of up and downvotes
			double score = (c.upvotes.length + 1.0) / (c.downvotes.length + 1.0);

			// new comments get a boost for about two hours (and comments
			// with the same basic score will stay sorted by time)
			// negative comments will only get a boost for around an hour
			if (score < 1.0) score += 0.5 / (c.age.total!"seconds" / (60.0 * 60));
			else score += 0.5 / (c.age.total!"seconds" / (2.0 * 60 * 60));

			return score;
		}

		void sortRec(Comment*[] comments)
		{
			comments.sort!((a, b) => getScore(a) > getScore(b));
			foreach (c; comments)
				sortRec(c.replies);
		}
		sortRec(ret.comments);
	}

	if (req.session) {
		ret.user.id = web.uid;
		ret.user.name = req.session.get!string(SessionVars.name, null);
		ret.user.email = req.session.get!string(SessionVars.email, null);
		ret.user.website = req.session.get!string(SessionVars.website, null);
	}

	if (web.settings.userStore) {
		auto u = web.settings.userStore.getLoggedInUser(req);
		if (!u.isNull) {
			ret.user = u;
			ret.user.registered = true;
		}
	}

	return ret;
}
