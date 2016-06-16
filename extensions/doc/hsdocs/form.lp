<head>
  <title>Lua Template Test</title>
</head>
<body>
<%= "<","!--" %><div align="center"><i><font color="#f00">Requires hs.httpserver.hsminweb:luaTemplateExtension("lp") to be enabled for your web server</font></i></div><%= "--",">" %>
<!-- <%= "--",">" %>

<form method="POST" action="<%= cgilua.mkurlpath("sample.lp") %>" enctype="multipart/form-data">
<table>
<tr><th colspan="2"><i>Form with file</i></th></tr>
<tr><td>An input field</td><td><input type="text" name="someText"></td></tr>
<tr><td rowspan="3">Check something</td><td><input type="checkbox" name="someChecks" value="yes">yes</td></tr>
<tr><td><input type="checkbox" name="someChecks" value="no">no</td></tr>
<tr><td><input type="checkbox" name="someChecks" value="maybe so">maybe so</td></tr>
<tr><td>A file</td><td><input type="file" name="someFile"></td></tr>
<tr><td colspan="2" align="right"><input type="submit" name="action" value="withFile"></td></tr>
</table>
</form>
<form method="POST" action="<%= cgilua.mkurlpath("sample.lp") %>">
<table>
<tr><th colspan="2"><i>Form without file</i></th></tr>
<tr><td>An input field</td><td><input type="text" name="someText"></td></tr>
<tr><td rowspan="3">Check something</td><td><input type="checkbox" name="someChecks" value="yes">yes</td></tr>
<tr><td><input type="checkbox" name="someChecks" value="no">no</td></tr>
<tr><td><input type="checkbox" name="someChecks" value="maybe so">maybe so</td></tr>
<!-- <tr><td>A file</td><td><input type="file" name="someFile"></td></tr> -->
<tr><td colspan="2" align="right"><input type="submit" name="action" value="withoutFile"></td></tr>
</table>
</form>

<%= "<","!--" %> -->
</body>

