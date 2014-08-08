build:
	coffee --join MMD.js --compile src/MMD.coffee src/MMD.*.coffee

watch:
	coffee --watch --join MMD.js --compile src/MMD.coffee src/MMD.*.coffee
