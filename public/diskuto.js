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
			var upbtn = comment.getElementsByClassName("vote-up")[0].getElementsByTagName("button")[0];
			var downbtn = comment.getElementsByClassName("vote-down")[0].getElementsByTagName("button")[0];
			upbtn.setAttribute("disabled", "");
			downbtn.setAttribute("disabled", "");
			if (dir < 0) downbtn.classList.add("chosen");
			else if (dir > 0) upbtn.classList.add("chosen");
		}
	}
	http.send(JSON.stringify({id: id, dir: dir}));
	return false;
}

function confirmReply(self)
{
	var comment = getClassAncestor(self, "comment");
	if (!comment) comment = getClassAncestor(self, "diskuto");
	var error = comment.getElementsByClassName("error")[0];
	error.textContent = "";

	var http = new XMLHttpRequest();
	http.open("POST", window.diskutoBaseURL + "/post", true);
	http.setRequestHeader("Content-type", "application/json");
	http.onerror = function() {
		error.textContent = "Error performing request.";
	}
	http.onload = function() {
		var reply = JSON.parse(this.responseText);
		if (reply.success) {
			var replies = comment.getElementsByClassName("replies")[0];
			var tmp = document.createElement('div');
			tmp.innerHTML = reply.rendered;
			replies.insertBefore(tmp.firstElementChild, replies.firstChild);
			var text = self.getElementsByTagName("textarea")[0];
			text.value = "";
			document.activeElement.blur();
			updateFormSnap(text);
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
	var comment = getClassAncestor(actionbar, "comment");
	var area = comment.getElementsByClassName("edit")[0];
	var text = area.getElementsByTagName("textarea")[0];
	var contents = comment.getElementsByClassName("contents")[0];
	area.style.display = "flex";
	text.style.height = contents.offsetHeight;
	actionbar.style.display = "none";
	contents.style.display = "none";
}

function cancelEdit(self)
{
	var comment = getClassAncestor(self, "comment");
	var area = comment.getElementsByClassName("edit")[0];
	var actionbar = comment.getElementsByClassName("action-bar")[0];
	var contents = comment.getElementsByClassName("contents")[0];
	area.style.display = "none";
	actionbar.style.display = "flex";
	contents.style.display = "block";
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
	var comment = getClassAncestor(self, "comment");
	var actionbar = comment.getElementsByClassName("action-bar")[0];
	var area = comment.getElementsByClassName("delete")[0];
	area.style.display = "block";
	actionbar.style.display = "none";
}

function cancelDelete(self)
{
	var comment = getClassAncestor(self, "comment");
	var area = comment.getElementsByClassName("delete")[0];
	var actionbar = comment.getElementsByClassName("action-bar")[0];
	actionbar.style.display = "flex";
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