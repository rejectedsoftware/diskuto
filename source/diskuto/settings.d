module diskuto.settings;

import diskuto.backend : DiskutoBackend;
import diskuto.userstore : DiskutoUserStore;
import vibe.data.json : Json;
import core.time : Duration, minutes;


class DiskutoSettings {
	string resourcePath = "public/"; // Path to Diskutp's "public" folder
	DiskutoBackend backend;
	DiskutoUserStore userStore;
	Json antispam;
	Duration softEditTimeLimit = 5.minutes;
	Duration hardEditTimeLimit = 15.minutes;
	bool onlyRegisteredMayVote = false;
}
