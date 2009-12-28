#!/bin/sh
# Copyright (c) 2009 Justin Poliey <jdp34@njit.edu>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

home_timeline="http://api.twitter.com/1/statuses/home_timeline.xml"
if [ ! -d ~/.twist ]; then
	mkdir ~/.twist
fi

# Transforms XML from the Twitter API status methods and makes them
# more awk-friendly. Takes the XML from stdin.
# Usage:
#   some-command | format_statuses
format_statuses()
{
	xmlstarlet sel -T -t -m "/statuses/status" -s D:N:- "id" -v "concat(id,'&#9;',user/screen_name,'&#9;',normalize-space(text))" -n
}

# Returns the number of <status> elements in the given XML. Takes
# the XML from stdin.
# Usage:
#   some-command | count_statuses
count_statuses()
{
	xmlstarlet sel -t -v "count(/statuses/status)"
}

# Builds and returns a URL used to fetch new tweets. Mostly used internally
# by the new_tweets function.
# Usage:
#   new_tweets_paged_url [page]
new_tweets_paged_url()
{
	local base_url lastid
	base_url="${home_timeline}?page=${1:-1}"
	if [ -f ~/.twist/lastid ]; then
		lastid=`cat ~/.twist/lastid`
	fi
	if [ -n "$lastid" ]; then
		base_url="${base_url}&since_id=${lastid}"
	fi
	echo $base_url
}

# Outputs all of the new tweets since the last time the function was
# executed, up to a limit of 5 pages (default).
# Usage:
#   new_tweets [page-limit] 
new_tweets()
{
	local page url xml statuses sinceid
	page=1
	url=`new_tweets_paged_url $page`
	xml=`curl -n $url 2> /dev/null`
	while [ `echo $xml | count_statuses` -gt 0 -a $page -lt `expr ${1:-5} + 1` ]; do
		statuses=`echo "$xml" | format_statuses`
		if [ "$page" -eq 1 ]; then
			sinceid=`echo $statuses | awk 'NR == 1 { print $1; exit; }'`
		fi
		echo "$statuses" | awk 'BEGIN { FS = "\t" }; {printf("%s: %s\n", $2, $3);}'
		page=`expr $page + 1`
		url=`new_tweets_paged_url $page`
		xml=`curl -n $url 2> /dev/null`
	done
	if [ -n "$sinceid" ]; then
		echo $sinceid > ~/.twist/lastid
	fi
}

new_tweets

