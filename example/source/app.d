import vibe.core.core : runApplication;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server : HTTPServerSettings, listenHTTP;
import vibe.http.session : MemorySessionStore;
import vibe.web.web : registerWebInterface, render;
import diskuto.web : registerDiskutoWeb;
import diskuto.backend : DiskutoBackend;
import diskuto.backends.mongodb : MongoDBBackend;

final class WebFrontend {
	private {
		DiskutoBackend m_diskuto;
	}

	this(DiskutoBackend diskuto)
	{
		m_diskuto = diskuto;
	}

	void get()
	{
		auto diskuto = m_diskuto;
		render!("home.dt", diskuto);
	}
}

void main()
{
	auto diskuto = new MongoDBBackend("mongodb://127.0.0.1/diskuto");

	auto router = new URLRouter;
	router.registerDiskutoWeb(diskuto);
	router.registerWebInterface(new WebFrontend(diskuto));
	router.get("*", serveStaticFiles("../public/"));

	auto settings = new HTTPServerSettings;
	settings.bindAddresses = ["127.0.0.1"];
	settings.port = 8080;
	settings.sessionStore = new MemorySessionStore;
	listenHTTP(settings, router);

	runApplication();
}
