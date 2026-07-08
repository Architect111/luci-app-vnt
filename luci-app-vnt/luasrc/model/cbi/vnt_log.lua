f = SimpleForm("vnt")
f.reset = false
f.submit = false
f:append(Template("vnt/vnt_log"))
return f
