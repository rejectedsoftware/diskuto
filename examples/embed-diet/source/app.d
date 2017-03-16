import vibe.core.core : runApplication;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server : HTTPServerRequest, HTTPServerSettings, listenHTTP;
import vibe.http.session : MemorySessionStore;
import vibe.web.web : errorDisplay, registerWebInterface, redirect, render, SessionVar;
import diskuto.web : registerDiskutoWeb, DiskutoWeb;
import diskuto.backend : DiskutoBackend;
import diskuto.backends.mongodb : MongoDBBackend;
import diskuto.userstore : DiskutoUserStore, StoredUser;
import diskuto.settings : DiskutoSettings;


final class ExampleUserStore : DiskutoUserStore {
	import std.algorithm.searching : countUntil;
	import std.typecons : Nullable;

	StoredUser[] users;

	this()
	{
		users ~= StoredUser("example-1", "John Doe", "john@doe.com", "http://johndoe.com", false);
		users ~= StoredUser("example-2", "Admin", "admin@example.com", "", true);
	}

	Nullable!StoredUser getLoggedInUser(HTTPServerRequest req)
	@trusted {
		scope (failure) assert(false);
		Nullable!StoredUser ret;
		if (req.session) {
			auto usr = req.session.get("userstore.loginUser", "");
			auto idx = users.countUntil!(u => u.email == usr);
			if (idx >= 0)
				ret = users[idx];
		}
		return ret;
	}

	Nullable!StoredUser getUserForEmail(string email)
	{
		Nullable!StoredUser ret;
		auto idx = users.countUntil!(u => u.email == email);
		if (idx >= 0)
			ret = users[idx];
		return ret;
	}
}

final class WebFrontend {
	private {
		DiskutoWeb m_diskuto;
		DiskutoSettings m_settings;
		SessionVar!(string, "userstore.loginUser") m_loginUser;
	}

	this(DiskutoWeb diskuto, DiskutoSettings settings)
	{
		m_diskuto = diskuto;
		m_settings = settings;
	}

	void get(string _error = null)
	{
		auto diskuto = m_diskuto;
		diskuto.setupRequest();
		render!("home.dt", diskuto, _error);
	}

	@errorDisplay!get
	void postLogin(string email, string password)
	{
		if (m_settings.userStore.getUserForEmail(email).isNull || password != "secret")
			throw new Exception("Invalid user name or password");
		m_loginUser = email;
		redirect("/");
	}

	void getLogout()
	{
		m_loginUser = null;
		redirect("/");
	}
}

void main()
{
	auto dsettings = new DiskutoSettings;
	dsettings.backend = new MongoDBBackend("mongodb://127.0.0.1/diskuto");
	dsettings.userStore = new ExampleUserStore;

	auto router = new URLRouter;
	auto diskutoweb = router.registerDiskutoWeb(dsettings);
	router.registerWebInterface(new WebFrontend(diskutoweb, dsettings));
	router.get("*", serveStaticFiles("../../public/"));

	auto settings = new HTTPServerSettings;
	settings.bindAddresses = ["0.0.0.0"];
	settings.port = 10888;
	settings.sessionStore = new MemorySessionStore;
	listenHTTP(settings, router);

	runApplication();
}

