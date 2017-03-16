module diskuto.settings;

import diskuto.backend : DiskutoCommentStore;
import diskuto.userstore : DiskutoUserStore;
import vibe.data.json : Json;
import core.time : Duration, minutes;


class DiskutoSettings {
	string resourcePath = "public/"; // Path to Diskutp's "public" folder
	DiskutoCommentStore commentStore;
	deprecated("Use commentStore instead.") alias backend = commentStore;
	DiskutoUserStore userStore;
	Json antispam;
	Duration softEditTimeLimit = 5.minutes;
	Duration hardEditTimeLimit = 15.minutes;
	bool onlyRegisteredMayVote = false;
}
