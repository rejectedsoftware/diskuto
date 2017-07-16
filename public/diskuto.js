function embedDiskuto()
{
	for (dok of document.getElementsByClassName("diskuto")) {
		var topic = dok.getAttribute("diskuto:topic");
		var base = dok.getAttribute("diskuto:base");

		var http = new XMLHttpRequest();
		http.open("GET", base + "/render_topic?base="+encodeURIComponent(base)+"&topic="+encodeURIComponent(topic), true);
		http.onerror = function() { dok.innerHTML = '<div class="error">Error performing request to load Diskuto comments.</div>'; }
		http.onload = function() {
			if (this.status < 400) {
				var tmp = document.createElement('div');
				tmp.innerHTML = this.responseText;
				dok.innerHTML = tmp.firstElementChild.innerHTML;
			} else {
				dok.innerHTML = '<div class="error">Error loading Diskuto comments.</div>';
			}
		}
		http.send();
	}
}

function updateFormSnap(self)
{
	var form = getClassAncestor(self, "reply-form");
	var has_focus = getClassAncestor(document.activeElement, "reply-form") == form;
	var has_text = self.value.length > 0;
	var expanded = has_focus || has_text;
	form.classList.toggle("expanded", expanded);
	if (!expanded) form.getElementsByTagName("textarea")[0].style.height = "";
	form.classList.toggle("controls-expanded", has_text);
}

function vote(self, dir)
{
	var ctx = getContext(self);
	var id = ctx.comment.id;
	var http = new XMLHttpRequest();
	http.open("POST", ctx.baseURL + "/vote", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			var count = ctx.comment.getElementsByClassName("vote-count")[0];
			var newcount = Number(count.textContent) + (dir < 0 ? -1 : dir > 0 ? 1: 0);
			count.textContent = newcount;
			count.classList.remove("neg", "bal", "pos");
			count.classList.add(newcount < 0 ? "neg" : newcount > 0 ? "pos" : "bal");
			var upbtn = ctx.comment.getElementsByClassName("vote-up")[0].getElementsByTagName("button")[0];
			var downbtn = ctx.comment.getElementsByClassName("vote-down")[0].getElementsByTagName("button")[0];
			if (reply.dir < 0) {
				downbtn.setAttribute("disabled", "");
				downbtn.classList.add("chosen");
			} else {
				downbtn.removeAttribute("disabled");
				downbtn.classList.remove("chosen");
			}
			if (reply.dir > 0) {
				upbtn.setAttribute("disabled", "");
				upbtn.classList.add("chosen");
			} else {
				upbtn.removeAttribute("disabled");
				upbtn.classList.remove("chosen");
			}
		}
	}
	http.send(JSON.stringify({id: id, dir: dir}));
	return false;
}

function confirmReply(self)
{
	var ctx = getContext(self);
	var error = ctx.comment.getElementsByClassName("error")[0];
	error.textContent = "";

	var http = new XMLHttpRequest();
	http.open("POST", ctx.baseURL + "/post", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onerror = function() {
		error.textContent = "Error performing request.";
	}
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			var replies = ctx.comment.getElementsByClassName("replies")[0];
			var tmp = document.createElement('div');
			tmp.innerHTML = reply.rendered;
			replies.insertBefore(tmp.firstElementChild, replies.firstChild);
			var text = self.getElementsByTagName("textarea")[0];
			text.value = "";
			document.activeElement.blur();
			updateFormSnap(text);
		} else {
			ctx.comment.getElementsByClassName("error")[0].textContent = reply.error;
		}
	}
	var data = {};
	for (inp of self.getElementsByTagName("input"))
		data[inp.getAttribute("name")] = inp.value;
	data["text"] = self.getElementsByTagName("textarea")[0].value;
	http.send(JSON.stringify(data));
	return false;
}

function showEdit(self)
{
	var ctx = getContext(self);
	var actionbar = ctx.comment.getElementsByClassName("action-bar")[0];
	var area = ctx.comment.getElementsByClassName("edit")[0];
	var text = area.getElementsByTagName("textarea")[0];
	var contents = ctx.comment.getElementsByClassName("contents")[0];
	area.style.display = "flex";
	text.style.height = contents.offsetHeight;
	actionbar.style.display = "none";
	contents.style.display = "none";
}

function cancelEdit(self)
{
	var ctx = getContext(self);
	var area = ctx.comment.getElementsByClassName("edit")[0];
	var actionbar = ctx.comment.getElementsByClassName("action-bar")[0];
	var contents = ctx.comment.getElementsByClassName("contents")[0];
	area.style.display = "none";
	actionbar.style.display = "flex";
	contents.style.display = "block";
}

function confirmEdit(self)
{
	var ctx = getContext(self);
	var http = new XMLHttpRequest();
	http.open("POST", ctx.baseURL + "/edit", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onerror = function() {
		ctx.comment.getElementsByClassName("error")[0].textContent = "Error performing request.";
	}
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			var tmp = document.createElement('div');
			tmp.innerHTML = reply.rendered;
			ctx.comment.getElementsByClassName("contents")[0].innerHTML = tmp.getElementsByClassName("contents")[0].innerHTML;
			cancelEdit(self);
		} else {
			ctx.comment.getElementsByClassName("error")[0].textContent = reply.error;
		}
	}
	var data = {};
	for (inp of self.getElementsByTagName("input"))
		data[inp.getAttribute("name")] = inp.value;
	data["text"] = self.getElementsByTagName("textarea")[0].value;
	http.send(JSON.stringify(data));
	return false;
}

function showDelete(self)
{
	var ctx = getContext(self);
	var actionbar = ctx.comment.getElementsByClassName("action-bar")[0];
	var area = ctx.comment.getElementsByClassName("delete")[0];
	area.style.display = "block";
	actionbar.style.display = "none";
}

function cancelDelete(self)
{
	var ctx = getContext(self);
	var area = ctx.comment.getElementsByClassName("delete")[0];
	var actionbar = ctx.comment.getElementsByClassName("action-bar")[0];
	actionbar.style.display = "flex";
	area.style.display = "none";
}

function confirmDelete(self)
{
	var ctx = getContext(self);
	var http = new XMLHttpRequest();
	http.open("POST", ctx.baseURL + "/delete", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onerror = function() {
		ctx.comment.getElementsByClassName("error")[0].textContent = "Error performing request.";
	}
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			ctx.comment.parentElement.removeChild(ctx.comment);
		} else {
			ctx.comment.getElementsByClassName("error")[0].textContent = reply.error;
		}
	}
	var data = {};
	for (inp of self.getElementsByTagName("input"))
		data[inp.getAttribute("name")] = inp.value;
	http.send(JSON.stringify(data));
	return false;
}

function setStatus(self, status)
{
	var ctx = getContext(self);
	var http = new XMLHttpRequest();
	http.open("POST", ctx.baseURL + "/set_status", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onerror = function() {
		ctx.comment.getElementsByClassName("error")[0].textContent = "Error performing request.";
	}
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			var right = ctx.comment.getElementsByClassName("right")[0];
			var cstatus = right.getElementsByClassName("comment-status")[0];
			if (status == "active") {
				if (cstatus != null)
					cstatus.parentElement.removeChild(cstatus)
			} else {
				if (cstatus == null) {
					var contents = right.getElementsByClassName("contents")[0];
					cstatus = document.createElement("div");
					cstatus.classList.add("comment-status");
					right.insertBefore(cstatus, contents);
				}
				cstatus.textContent = "Set status: " + status;
			}
		} else {
			ctx.comment.getElementsByClassName("error")[0].textContent = reply.error;
		}
	}
	var data = {
		id: ctx.comment.getAttribute("id"),
		status: status
	}
	http.send(JSON.stringify(data));
	return false;
}

function getClassAncestor(element, cls)
{
	while (element) {
		if (element.classList.contains(cls))
			return element;
		else if (element.classList.contains("diskuto"))
			return null;
		element = element.parentElement;
	}
	return element;
}

function getContext(element)
{
	var ret = {};
	ret.diskuto = getClassAncestor(element, "diskuto");
	ret.comment = getClassAncestor(element, "comment");
	if (!ret.comment) ret.comment = ret.diskuto;
	ret.baseURL = ret.diskuto.getAttribute("diskuto:base");
	return ret;
}
