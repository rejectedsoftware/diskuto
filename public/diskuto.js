function updateFormSnap(self)
{
	var form = getClassAncestor(self, "reply-form");
	var has_focus = getClassAncestor(document.activeElement, "reply-form") == form;
	var has_text = self.value.length > 0;
	console.log(has_focus);
	console.log(has_text);
	form.classList.toggle("snapped", !has_focus && !has_text);
	form.classList.toggle("controls-snapped", !has_text);
}

function vote(self, dir)
{
	var comment = getClassAncestor(self, "comment");
	var id = comment.id;
	var http = new XMLHttpRequest();
	http.open("POST", window.diskutoBaseURL + "/vote", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			var count = comment.getElementsByClassName("vote-count")[0];
			var newcount = Number(count.textContent) + (dir < 0 ? -1 : dir > 0 ? 1: 0);
			count.textContent = newcount;
			count.classList.remove("neg", "bal", "pos");
			count.classList.add(newcount < 0 ? "neg" : newcount > 0 ? "pos" : "bal");
			var voting = comment.getElementsByClassName("voting")[0];
			var upbtn = voting.getElementsByClassName("vote-up")[0].getElementsByTagName("button")[0];
			var downbtn = voting.getElementsByClassName("vote-down")[0].getElementsByTagName("button")[0];
			upbtn.setAttribute("disabled", "");
			downbtn.setAttribute("disabled", "");
			if (dir < 0) downbtn.classList.add("chosen");
			else if (dir > 0) upbtn.classList.add("chosen");
		}
	}
	http.send(JSON.stringify({id: id, dir: dir}));
	return false;
}

function showReply(self)
{
	var actionbar = getClassAncestor(self, "action-bar");
	var area = actionbar.parentElement.getElementsByClassName("reply")[0];
	area.style.display = "block";
	actionbar.style.display = "none";
}

function cancelReply(self)
{
	var area = getClassAncestor(self, "reply");
	var comment = area.parentElement;
	var actionbar = comment.getElementsByClassName("action-bar")[0];
	actionbar.style.display = "block";
	area.style.display = "none";
}

function confirmReply(self)
{
	var comment = getClassAncestor(self, "comment");
	if (!comment) comment = getClassAncestor(self, "diskuto");
	var http = new XMLHttpRequest();
	http.open("POST", window.diskutoBaseURL + "/post", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onerror = function() {
		comment.getElementsByClassName("error")[0].textContent = "Error performing request.";
	}
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			var replies = comment.getElementsByClassName("replies")[0];
			var tmp = document.createElement('div');
			tmp.innerHTML = reply.rendered;
			replies.insertBefore(tmp.firstElementChild, replies.firstChild);
			self.getElementsByTagName("textarea")[0].value = "";
			cancelReply(self);
		} else {
			comment.getElementsByClassName("error")[0].textContent = reply.error;
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
	var actionbar = getClassAncestor(self, "action-bar");
	var area = actionbar.parentElement.getElementsByClassName("edit")[0];
	area.style.display = "block";
	actionbar.style.display = "none";
}

function cancelEdit(self)
{
	var area = getClassAncestor(self, "edit");
	var comment = area.parentElement;
	var actionbar = comment.getElementsByClassName("action-bar")[0];
	actionbar.style.display = "block";
	area.style.display = "none";
}

function confirmEdit(self)
{
	var comment = getClassAncestor(self, "comment");
	if (!comment) comment = getClassAncestor(self, "diskuto");
	var http = new XMLHttpRequest();
	http.open("POST", window.diskutoBaseURL + "/edit", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onerror = function() {
		comment.getElementsByClassName("error")[0].textContent = "Error performing request.";
	}
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			var tmp = document.createElement('div');
			tmp.innerHTML = reply.rendered;
			comment.getElementsByClassName("contents")[0].innerHTML = tmp.getElementsByClassName("contents")[0].innerHTML;
			self.reset();
			cancelEdit(self);
		} else {
			comment.getElementsByClassName("error")[0].textContent = reply.error;
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
	var actionbar = getClassAncestor(self, "action-bar");
	var area = actionbar.parentElement.getElementsByClassName("delete")[0];
	area.style.display = "block";
	actionbar.style.display = "none";
}

function cancelDelete(self)
{
	var area = getClassAncestor(self, "delete");
	var comment = area.parentElement;
	var actionbar = comment.getElementsByClassName("action-bar")[0];
	actionbar.style.display = "block";
	area.style.display = "none";
}

function confirmDelete(self)
{
	var comment = getClassAncestor(self, "comment");
	if (!comment) comment = getClassAncestor(self, "diskuto");
	var http = new XMLHttpRequest();
	http.open("POST", window.diskutoBaseURL + "/delete", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onerror = function() {
		comment.getElementsByClassName("error")[0].textContent = "Error performing request.";
	}
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			comment.parentElement.removeChild(comment);
		} else {
			comment.getElementsByClassName("error")[0].textContent = reply.error;
		}
	}
	var data = {};
	for (inp of self.getElementsByTagName("input"))
		data[inp.getAttribute("name")] = inp.value;
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