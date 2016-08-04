.PHONY: docs deploy-docs

# compile the docs using jazzy
docs:
	# prereq: gem install jazzy
	jazzy \
		--clean \
		--min-acl=public \
		--author Hipmunk \
		--author_url https://hipmunk.com \
		--github_url https://github.com/Hipmunk/HIPInstanceLocator \
		--github-file-prefix https://github.com/Hipmunk/HIPInstanceLocator/tree/master \
		--module HIPInstanceLocator \
		--module-version 1.0.1 \
		--skip-undocumented \
		--root-url https://hipmunk.github.com/HIPInstanceLocator
		# --objc \
		# --umbrella-header HIPInstanceLocator/HIPInstanceLocator.h \
		# --framework-root . \
		# --sdk=iphone

# Uploads docs to your origin/gh-pages branch
deploy-docs: docs
	# prereq: pip install ghp-import
	ghp-import docs \
		-n -p \
		-m "Update docs" \
		-r origin \
		-b gh-pages
