module diskuto.dietutils;

import diskuto.backend : CommentStatus, DiskutoBackend, StoredComment;
import core.time : Duration;
import std.datetime : SysTime;

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
		this.age = now - comment.time;
		this.avatarWidth = 48;
		this.avatarHeight = 48;
		this.avatarID = comment.email.length ? comment.email : comment.userID ~ "@diskuto";
	}

	bool isVisibleTo(StoredComment.UserID user)
	{
		//if (isModerator(user)) return true;
		if (comment.status == CommentStatus.deleted) return false;
		if (comment.userID == user) return true;
		return comment.status == CommentStatus.active;
	}
}

auto getCommentsContext(DiskutoBackend backend, string topic)
{
	import diskuto.backend : StoredComment;
	import diskuto.dietutils : Comment;
	import std.datetime : Clock, UTC;
	import std.algorithm.sorting : sort;

	static struct Info {
		Comment*[] comments;
	}

	SysTime now = Clock.currTime(UTC());

	auto dbcomments = backend.getCommentsForTopic(topic);
	auto comments = new Comment[](dbcomments.length);
	size_t curidx;
	Info ret;
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

	double getScore(Comment* c) {
		// basic sortig based on the ratio of up and downvotes
		double score = (c.upvotes.length + 1.0) / (c.downvotes.length + 1.0);

		// new comments get a boost for about a week (and comments
		// with the same basic score will stay sorted by time)
		// negative comments will only get a boost for around an hour
		auto age = now - c.time;
		if (score < 1.0) score += 0.5 / (age.total!"seconds" / (60.0 * 60));
		else score += 0.5 / (age.total!"seconds" / (7.0 * 24 * 60 * 60));

		return score;
	}

	void sortRec(Comment*[] comments)
	{
		comments.sort!((a, b) => getScore(a) > getScore(b));
		foreach (c; comments)
			sortRec(c.replies);
	}
	sortRec(ret.comments);

	return ret;
}
