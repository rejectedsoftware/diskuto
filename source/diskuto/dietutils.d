module diskuto.dietutils;

import diskuto.backend : DiskutoBackend, StoredComment;
import core.time : Duration;

struct Comment {
	StoredComment comment;
	alias comment this;

	Duration age;
	string avatarURL;
	int avatarWidth;
	int avatarHeight;
	Comment*[] replies;
}

auto getCommentsContext(DiskutoBackend backend, string topic)
{
	import diskuto.backend : StoredComment;
	import diskuto.dietutils : Comment;
	import std.datetime : Clock, SysTime, UTC;
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
		auto id = curidx++;
		map[c.id] = id;
		comments[id].age = now - c.time;
		comments[id].comment = c;
		comments[id].avatarWidth = 48;
		comments[id].avatarHeight = 48;
		comments[id].avatarURL = getGravatarURL(comments[id].email.length ? comments[id].email : comments[id].userID ~ "@diskuto", 64);
		if (!c.replyTo.length) ret.comments ~= &comments[id];
		else {
			if (auto rti = c.replyTo in map)
				comments[*rti].replies ~= &comments[id];
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

string getGravatarURL(string email, int size)
{
	import std.digest.md : hexDigest, MD5;
	import std.format : format;
	import std.string : toLower;

	return format("https://www.gravatar.com/avatar/%s?d=retro&amp;s=%s", toLower(hexDigest!MD5(toLower(email)).idup), size);
}
