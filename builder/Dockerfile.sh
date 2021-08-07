#!/bin/sh

. ../utils/Dockerfile-utils.sh

# Node releases: https://nodejs.org/en/about/releases/
# This should normally be the Active LTS release,
# or optionally the latest Current release,
# if that release will become an Active LTS in future.
NODE_VERSION="$(cat node-version.txt )"

# JSDoc documentation is generated by jsdoc:
NPM_PACKAGES="$NPM_PACKAGES jsdoc"
APT_PACKAGES="$APT_PACKAGES"

# Several repositories are build with Google's Closure compiler:
NPM_PACKAGES="$NPM_PACKAGES google-closure-compiler"
APT_PACKAGES="$APT_PACKAGES inotify-tools"

# Unit tests are use Jasmine:
NPM_PACKAGES="$NPM_PACKAGES jasmine"
APT_PACKAGES="$APT_PACKAGES"

# Running tests in Chrome would significantly increase size, without adding much value:
#NPM_PACKAGES="$NPM_PACKAGES puppeteer"
#APT_PACKAGES="$APT_PACKAGES chromium"

# Header:
cat <<EOF
FROM node:$NODE_VERSION
RUN true \\
EOF

# JSDoc timestamps all documents.  To generate a repeatable build, we need a fake timestamp:
if echo "$NPM_PACKAGES" | grep -q jsdoc
then cat <<EOF
   \\
&& git clone --depth 1 https://github.com/wolfcw/libfaketime.git /tmp/libfaketime \\
&& sed -i -e 's/\/usr\/local/\/tmp\/libfaketime/' /tmp/libfaketime/Makefile /tmp/libfaketime/*/Makefile \\
&& make -j -C /tmp/libfaketime/src \\
&& ln -s . /tmp/libfaketime/lib \\
&& ln -s src /tmp/libfaketime/faketime \\
EOF
fi

install_npm_packages $NPM_PACKAGES

# Configure puppetteer:
if echo "$NPM_PACKAGES" | grep -q puppeteer
then cat <<EOF
   \\
&& cd /usr/local/lib/node_modules/puppeteer && PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true node install.js \\
EOF
fi

install_apt_packages $APT_PACKAGES

if echo "$APT_PACKAGES" | grep -q 'chromium'
then cat <<EOF
   \\
&& { echo '#!/bin/sh' ; echo '/usr/bin/chromium --no-sandbox "\$@"' ; } > /usr/bin/chromium-no-sandbox \\
&& chmod 755 /usr/bin/chromium-no-sandbox \\
EOF
fi

footer

cat <<EOF
COPY root /
RUN chmod 755 /build-sleepdiary.sh /entrypoint.sh /app/bin/entrypoint.sh
WORKDIR /app
EOF
