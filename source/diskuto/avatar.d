module diskuto.avatar;

import std.range : isOutputRange;

void generateAvatar(R)(R dst, string id)
	if (isOutputRange!(R, char))
{
	generateSVGAvatar(dst, id);
	//generateGravatar(dst, id);
}

void generateGravatar(R)(R dst, string id)
	if (isOutputRange!(R, char))
{
	import std.format : formattedWrite;
	import std.string : toLower;
	import std.digest.md : MD5, hexDigest;

	dst.formattedWrite(`<img class="avatar" src="https://www.gravatar.com/avatar/%s?d=retro&amp;s=%s", alt="Avatar"/>`,
		toLower(hexDigest!MD5(toLower(id)).idup), 64);
}

void generateSVGAvatar(R)(R dst, string id)
	if (isOutputRange!(R, char))
{
	import std.format : formattedWrite;

	static immutable(byte)[] matrix = [
	   2, 9, 9, 4,
	   3, 4, 2, 1,
	   3, 8, 4, 4,
	   0, 1, 3, 6,
	   0, 0, 2, 9,
	   1, 6, 1, 1,
	   1, 4, 9, 7,
	   0, 2, 7, 8,
	];

	uint rnd = 1534789237;
	foreach (char ch; id) rnd += ch * 2671475843;
	int uniform(uint lo, uint hi)() {
		auto ret = rnd % (hi - lo) + lo;
		rnd += 2860486313;
		rnd *= 1500450271;
		return ret;
	}

	int[3] bg = [255, 255, 255];
	int[3] fg = [uniform!(60, 180), uniform!(60, 180), uniform!(60, 180)];
	int[3] fg2 = (fg[] + bg[]) / 2;

	dst.put(`<svg class="avatar" version="1.1" viewBox="0 0 64 64" preserveAspectRatio="xMinYMin meet">`);
	dst.formattedWrite(`<rect x="0" y="0" width="64" height="64" style="fill: #%02x%02x%02x"></rect>`, bg[0], bg[1], bg[2]);

	void drawRect(int x, int y, int w, int h, ref int[3] c) {
		dst.formattedWrite(`<rect x="%s", y="%s", width="%s", height="%s" style="fill: #%02x%02x%02x" rx="2" ry="2"/>`, x, y, w, h, c[0], c[1], c[2]);
	}

	foreach (i, v; matrix) {
		int col = cast(int)i % 4;
		int row = cast(int)i / 4;
		int dice = uniform!(0, 10);

		if (dice < v) {
			int x = col * 8 + 4;
			int x2 = (6 - col) * 8 + 4;
			int y = row * 7 + 4;
			int w = 8;
			int h = 7;
			drawRect(x, y, w, h, fg);
			if (x != x2) drawRect(x2, y, w, h, fg);
		}
	}

	dst.put(`</svg>`);
}
