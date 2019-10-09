import vibe.core.core : runApplication;
import vibe.data.json : parseJsonString;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse, HTTPServerSettings, listenHTTP;
import vibe.http.session : MemorySessionStore;
import vibe.web.web : errorDisplay, registerWebInterface, redirect, render, SessionVar;
import diskuto.web : registerDiskutoWeb, DiskutoWeb;
import diskuto.commentstore : DiskutoCommentStore;
import diskuto.commentstores.mongodb : MongoDBCommentStore;
import diskuto.userstore : DiskutoUserStore, StoredUser;
import diskuto.settings : DiskutoSettings;


final class WebFrontend {
	private {
		DiskutoWeb m_diskuto;
		DiskutoSettings m_settings;
	}

	this(DiskutoWeb diskuto, DiskutoSettings settings)
	{
		m_diskuto = diskuto;
		m_settings = settings;
	}

	void get(HTTPServerRequest req, HTTPServerResponse res, string _error = null)
	{
		import vibe.stream.wrapper : streamOutputRange;

		m_diskuto.setupRequest();

		res.contentType = "text/html; charset=UTF-8";

		auto dst = streamOutputRange(res.bodyWriter);
		dst.put("<html><head><title>Diskuto raw embedding example</title></head>");
		dst.put("<body><p>The comment section is embedded below:</p>");
		m_diskuto.generateInclude(dst, req, "example");
		dst.put("</body></html>");
	}
}

void main()
{
	auto dsettings = new DiskutoSettings;
	dsettings.commentStore = new MongoDBCommentStore("mongodb://127.0.0.1/diskuto");
	dsettings.antispam = parseJsonString(`[{"filter": "blacklist", "settings": {"words": ["sex", "drugs", "rock", "roll"]}}]`);

	auto router = new URLRouter;
	auto diskutoweb = router.registerDiskutoWeb(dsettings);
	router.registerWebInterface(new WebFrontend(diskutoweb, dsettings));

	auto settings = new HTTPServerSettings;
	settings.bindAddresses = ["127.0.0.1"];
	settings.port = 8080;
	settings.sessionStore = new MemorySessionStore;
	listenHTTP(settings, router);

	runApplication();
}
