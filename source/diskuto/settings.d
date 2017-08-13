module diskuto.settings;

import diskuto.commentstore : DiskutoCommentStore;
import diskuto.userstore : DiskutoUserStore;
import vibe.data.json : Json;
import core.time : Duration, minutes;


/** Contains all available properties to configure a Diskuto instance.
*/
class DiskutoSettings {
	/// Path to Diskuto's "public" folder
	NativePath resourcePath = "public/";

	/// Used for permanent storage of all comments
	DiskutoCommentStore commentStore;
	
	deprecated("Use .commentStore instead.") alias backend = commentStore;

	/// Used to query information about registered or unregistered users
	DiskutoUserStore userStore;

	/// Settings to use for AntiSpam
	Json antispam;

	/// Maximum editing time as presented to the user
	Duration softEditTimeLimit = 5.minutes;

	/** Maximum editing time as enforced by the server

		Note that synchronization to external services will be
		delayed by this amount of time. However, there should
		be some slack room, so that there is still some time
		to author changes when someone begins to edit a
		message after almost `softEditTimeLimit`.
	*/
	Duration hardEditTimeLimit = 15.minutes;
	
	/// Allow voting only for registered users
	bool onlyRegisteredMayVote = false;
	
	/// Settings to use for sending e-mails
	SMTPClientSettings smtpSettings;
	
	/// E-Mail addresses to be notified of new messages
	string[] notificationEmails;
	
	/// E-Mail address to use as the "from" field
	string notificationSender;
}
