#!/usr/bin/env bash -x

# A simple HTTP server written in bash.
#
# Bashttpd will serve text files, and most binaries as Base64 encoded.
#
# Avleen Vig, 2012-09-13
#
#

if [ "$(id -u)" = "0" ]; then
   echo "Hold on, tiger! Don't run this as root, k?" 1>&2
   exit 1
fi


DOCROOT=/var/www/html

DATE=$( date +"%a, %d %b %Y %H:%M:%S %Z" )
REPLY_HEADERS="Date: ${DATE}
Expires: ${DATE}
Server: Slash Bin Slash Bash"

function filter_url() {
    URL_PATH=$1
    URL_PATH=${URL_PATH//[^a-zA-Z0-9_~\-\.\/]/}
}

function get_content_type() {
    URL_PATH=$1
    CONTENT_TYPE=$( file -b --mime-type ${URL_PATH} )
}

function get_content_body() {
    URL_PATH=$1
    CONTENT_TYPE=$2
    if [[ ${CONTENT_TYPE} =~ "^text" ]]; then
        CONTENT_BODY="$( cat ${URL_PATH} )"
    else
        CONTENT_BODY="$( cat ${URL_PATH} )"
    fi
}

function get_content_length() {
    CONTENT_BODY="$1"
    CONTENT_LENGTH="$((${#CONTENT_BODY} + 1))"
}

while read line; do
    # If we've reached the end of the headers, break.
    line=$( echo ${line} | tr -d '\r' )
    echo ${line} | grep '^$' > /dev/null
    if [ $? -eq 0 ]; then
        break
    fi

    # Look for a GET request
    echo ${line} | grep ^GET > /dev/null
    if [ $? -eq 0 ]; then
        URL_PATH="${DOCROOT}$( echo ${line} | cut -d' ' -f2 )"
        filter_url ${URL_PATH}
    fi
done

if [[ "$URL_PATH" == *..* ]]; then
    echo "HTTP/1.0 400 Bad Request\rn"
    echo "${REPLY_HEADERS}"
    exit
fi

# If URL_PATH isn't set, return 400
if [ -z "${URL_PATH}" ]; then
    echo "HTTP/1.0 400 Bad Request"
    echo "${REPLY_HEADERS}"
    echo
    exit
fi

# Serve index file if exists in requested directory
if [ -d ${URL_PATH} -a -f ${URL_PATH}/index.html -a -r ${URL_PATH}/index.html ]; then
    URL_PATH=${URL_PATH}/index.html
fi

# Check the URL requested.
# If it's a text file, serve it directly.
# If it's a binary file, base64 encode it first.
# If it's a directory, perform an "ls -la".
# Otherwise, return a 404.
if [ -f ${URL_PATH} -a -r ${URL_PATH} ]; then
    # Return 200 and file contents
    get_content_type "${URL_PATH}"
    get_content_body "${URL_PATH}" "${CONTENT_TYPE}"
    get_content_length "${CONTENT_BODY}"
    HTTP_RESPONSE="HTTP/1.0 200 OK"
elif [ -f ${URL_PATH} -a ! -r ${URL_PATH} ]; then
    # Return 403 for unreadable files
    echo "HTTP/1.0 403 Forbidden"
    echo "${REPLY_HEADERS}"
    echo
    exit
elif [ -d ${URL_PATH} ]; then
    # Return 200 for directory listings.
    # If `tree` is installed, use that for pretty output.
    if [ -x "$( which tree )" ]; then
        CONTENT_TYPE="text/html"
        CONTENT_BODY=$( tree -H "" -L 1 --du -D ${URL_PATH} )
    else
        CONTENT_TYPE="text/plain"
        CONTENT_BODY=$( ls -la ${URL_PATH} )
    fi
    get_content_length "$CONTENT_BODY"
    HTTP_RESPONSE="HTTP/1.0 200 OK"
elif [ -d ${URL_PATH} -a ! -x ${URL_PATH} ]; then
    # Return 403 for non-listable directories
    echo "HTTP/1.0 403 Forbidden"
    echo "${REPLY_HEADERS}"
    echo
    exit
else
    echo "HTTP/1.0 404 Not Found"
    echo "${REPLY_HEADERS}"
    echo
    exit
fi

echo -n "${HTTP_RESPONSE}"
echo "${REPLY_HEADERS}"
#echo "Content-length: ${CONTENT_LENGTH}"
echo "Content-type: ${CONTENT_TYPE}"
echo
echo "${CONTENT_BODY}"
exit
