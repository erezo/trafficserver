HTTP Proxy Caching
******************

.. Licensed to the Apache Software Foundation (ASF) under one
   or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at
 
   http://www.apache.org/licenses/LICENSE-2.0
 
  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.

Web proxy caching enables you to store copies of frequently-accessed web
objects (such as documents, images, and articles) and then serve this
information to users on demand. It improves performance and frees up
Internet bandwidth for other tasks.

This chapter discusses the following topics:

.. toctree::
   :maxdepth: 2

Understanding HTTP Web Proxy Caching
====================================

Internet users direct their requests to web servers all over the
Internet. A caching server must act as a **web proxy server** so it can
serve those requests. After a web proxy server receives requests for web
objects, it either serves the requests or forwards them to the **origin
server** (the web server that contains the original copy of the
requested information). The Traffic Server proxy supports **explicit
proxy caching**, in which the user's client software must be configured
to send requests directly to the Traffic Server proxy. The following
overview illustrates how Traffic Server serves a request.

1. Traffic Server receives a client request for a web object.

2. Using the object address, Traffic Server tries to locate the
   requested object in its object database (**cache**).

3. If the object is in the cache, then Traffic Server checks to see if
   the object is fresh enough to serve. If it is fresh, then Traffic
   Server serves it to the client as a **cache hit** (see the figure
   below).

   .. figure:: ../static/images/admin/cache_hit.jpg
      :align: center
      :alt: A cache hit

      A cache hit
4. If the data in the cache is stale, then Traffic Server connects to
   the origin server and checks if the object is still fresh (a
   **revalidation**). If it is, then Traffic Server immediately sends
   the cached copy to the client.

5. If the object is not in the cache (a **cache miss**) or if the server
   indicates the cached copy is no longer valid, then Traffic Server
   obtains the object from the origin server. The object is then
   simultaneously streamed to the client and the Traffic Server local
   cache (see the figure below). Subsequent requests for the object can
   be served faster because the object is retrieved directly from cache.

   .. figure:: ../static/images/admin/cache_miss.jpg
      :align: center
      :alt: A cache miss

      A cache miss

Caching is typically more complex than the preceding overview suggests.
In particular, the overview does not discuss how Traffic Server ensures
freshness, serves correct HTTP alternates, and treats requests for
objects that cannot/should not be cached. The following sections discuss
these issues in greater detail.

Ensuring Cached Object Freshness
================================

When Traffic Server receives a request for a web object, it first tries
to locate the requested object in its cache. If the object is in cache,
then Traffic Server checks to see if the object is fresh enough to
serve. For HTTP objects, Traffic Server supports optional
author-specified expiration dates. Traffic Server adheres to these
expiration dates; otherwise, it picks an expiration date based on how
frequently the object is changing and on administrator-chosen freshness
guidelines. Objects can also be revalidated by checking with the origin
server to see if an object is still fresh.

HTTP Object Freshness
---------------------

Traffic Server determines whether an HTTP object in the cache is fresh
by:

-  **Checking the ``Expires`` or ``max-age`` header**

   Some HTTP objects contain ``Expires`` headers or ``max-age`` headers
   that explicitly define how long the object can be cached. Traffic
   Server compares the current time with the expiration time to
   determine if the object is still fresh.

-  **Checking the ``Last-Modified`` / ``Date`` header**

   If an HTTP object has no ``Expires`` header or ``max-age`` header,
   then Traffic Server can calculate a freshness limit using the
   following formula:

   ::
       freshness_limit = ( date - last_modified ) * 0.10   

   where *date* is the date in the object's server response header
   and *last_modified* is the date in the ``Last-Modified`` header.
   If there is no ``Last-Modified`` header, then Traffic Server uses the
   date the object was written to cache. The value ``0.10`` (10 percent)
   can be increased or reduced to better suit your needs (refer to
   `Modifying the Aging Factor for Freshness
   Computations <#ModifyingAgingFactorFreshnessComputations>`_).

   The computed freshness limit is bound by a minimum and maximum value
   - refer to `Setting an Absolute Freshness Limit`_ for more information.

-  **Checking the absolute freshness limit**

   For HTTP objects that do not have ``Expires`` headers or do not have
   both ``Last-Modified`` and ``Date`` headers, Traffic Server uses a
   maximum and minimum freshness limit (refer to `Setting an Absolute Freshness Limit`_).

-  **Checking revalidate rules in the `cache.config`_ file**

   Revalidate rules apply freshness limits to specific HTTP objects. You
   can set freshness limits for objects originating from particular
   domains or IP addresses, objects with URLs that contain specified
   regular expressions, objects requested by particular clients, and so
   on (refer to `cache.config`_).

Modifying Aging Factor for Freshness Computations
-------------------------------------------------

If an object does not contain any expiration information, then Traffic
Server can estimate its freshness from the ``Last-Modified`` and
``Date`` headers. By default, Traffic Server stores an object for 10% of
the time that elapsed since it last changed. You can increase or reduce
the percentage according to your needs.

To modify the aging factor for freshness computations

1. Edit the following variables in `records.config`_

   -  `proxy.config.http.cache.heuristic_lm_factor`_

2. Run the ``traffic_line -x`` command to apply the configuration
   changes.

Setting absolute Freshness Limits
---------------------------------

Some objects do not have ``Expires`` headers or do not have both
``Last-Modified`` and ``Date`` headers. To control how long these
objects are considered fresh in the cache, specify an **absolute
freshness limit**.

To specify an absolute freshness limit

1. Edit the following variables in `records.config`_ 

   -  `proxy.config.http.cache.heuristic_min_lifetime`_
   -  `proxy.config.http.cache.heuristic_max_lifetime`_

2. Run the ``traffic_line -x`` command to apply the configuration
   changes.

Specifying Header Requirements
------------------------------

To further ensure freshness of the objects in the cache, configure
Traffic Server to cache only objects with specific headers. By default,
Traffic Server caches all objects (including objects with no headers);
you should change the default setting only for specialized proxy
situations. If you configure Traffic Server to cache only HTTP objects
with ``Expires`` or ``max-age`` headers, then the cache hit rate will be
noticeably reduced (since very few objects will have explicit expiration
information).

To configure Traffic Server to cache objects with specific headers

1. Edit the following variable in `records.config`_

   -  `proxy.config.http.cache.required_headers`_

2. Run the ``traffic_line -x`` command to apply the configuration
   changes.

Cache-Control Headers
---------------------

Even though an object might be fresh in the cache, clients or servers
often impose their own constraints that preclude retrieval of the object
from the cache. For example, a client might request that a object *not*
be retrieved from a cache, or if it does, then it cannot have been
cached for more than 10 minutes. Traffic Server bases the servability of
a cached object on ``Cache-Control`` headers that appear in both client
requests and server responses. The following ``Cache-Control`` headers
affect whether objects are served from cache:

-  The ``no-cache`` header, sent by clients, tells Traffic Server that
   it should not to serve any objects directly from the cache;
   therefore, Traffic Server will always obtain the object from the
   origin server. You can configure Traffic Server to ignore client
   ``no-cache`` headers - refer to `Configuring Traffic Server to Ignore Client no-cache Headers`_
   for more information.

-  The ``max-age`` header, sent by servers, is compared to the object
   age. If the age is less than ``max-age``, then the object is fresh
   and can be served.

-  The ``min-fresh`` header, sent by clients, is an **acceptable
   freshness tolerance**. This means that the client wants the object to
   be at least this fresh. Unless a cached object remains fresh at least
   this long in the future, it is revalidated.

-  The ``max-stale`` header, sent by clients, permits Traffic Server to
   serve stale objects provided they are not too old. Some browsers
   might be willing to take slightly stale objects in exchange for
   improved performance, especially during periods of poor Internet
   availability.

Traffic Server applies ``Cache-Control`` servability criteria
***after*** HTTP freshness criteria. For example, an object might be
considered fresh but will not be served if its age is greater than its
``max-age``.

Revalidating HTTP Objects
-------------------------

When a client requests an HTTP object that is stale in the cache,
Traffic Server revalidates the object. A **revalidation** is a query to
the origin server to check if the object is unchanged. The result of a
revalidation is one of the following:

-  If the object is still fresh, then Traffic Server resets its
   freshness limit and serves the object.

-  If a new copy of the object is available, then Traffic Server caches
   the new object (thereby replacing the stale copy) and simultaneously
   serves the object to the client.

-  If the object no longer exists on the origin server, then Traffic
   Server does not serve the cached copy.

-  If the origin server does not respond to the revalidation query, then
   Traffic Server serves the stale object along with a
   ``111 Revalidation Failed`` warning.

By default, Traffic Server revalidates a requested HTTP object in the
cache if it considers the object to be stale. Traffic Server evaluates
object freshness as described in `HTTP Object Freshness`_.
You can reconfigure how Traffic
Server evaluates freshness by selecting one of the following options:

-  Traffic Server considers all HTTP objects in the cache to be stale:
   always revalidate HTTP objects in the cache with the origin server.
-  Traffic Server considers all HTTP objects in the cache to be fresh:
   never revalidate HTTP objects in the cache with the origin server.
-  Traffic Server considers all HTTP objects without ``Expires`` or
   ``Cache-control`` headers to be stale: revalidate all HTTP objects
   without ``Expires`` or ``Cache-Control`` headers.

To configure how Traffic Server revalidates objects in the cache, you
can set specific revalidation rules in `cache.config`_.

To configure revalidation options

1. Edit the following variable in `records.config`_

   -  `proxy.config.http.cache.when_to_revalidate`_

2. Run the ``traffic_line -x`` command to apply the configuration
   changes.

Scheduling Updates to Local Cache Content
=========================================

To further increase performance and to ensure that HTTP objects are
fresh in the cache, you can use the **Scheduled Update** option. This
configures Traffic Server to load specific objects into the cache at
scheduled times. You might find this especially beneficial in a reverse
proxy setup, where you can *preload* content you anticipate will be in
demand.

To use the Scheduled Update option, you must perform the following
tasks.

-  Specify the list of URLs that contain the objects you want to
   schedule for update,
-  the time the update should take place,
-  and the recursion depth for the URL.
-  Enable the scheduled update option and configure optional retry
   settings.

Traffic Server uses the information you specify to determine URLs for
which it is responsible. For each URL, Traffic Server derives all
recursive URLs (if applicable) and then generates a unique URL list.
Using this list, Traffic Server initiates an HTTP ``GET`` for each
unaccessed URL. It ensures that it remains within the user-defined
limits for HTTP concurrency at any given time. The system logs the
completion of all HTTP ``GET`` operations so you can monitor the
performance of this feature.

Traffic Server also provides a **Force Immediate Update** option that
enables you to update URLs immediately without waiting for the specified
update time to occur. You can use this option to test your scheduled
update configuration (refer to `Forcing an Immediate Update`_).

Configuring the Scheduled Update Option
---------------------------------------

To configure the scheduled update option

1. Edit `update.config`_ to
   enter a line in the file for each URL you want to update.
2. Edit the following variables in `records.config`_

   -  `proxy.config.update.enabled`_
   -  `proxy.config.update.retry_count`_
   -  `proxy.config.update.retry_interval`_
   -  `proxy.config.update.concurrent_updates`_

3. Run the ``traffic_line -x`` command to apply the configuration
   changes.

Forcing an Immediate Update
---------------------------

Traffic Server provides a **Force Immediate Update** option that enables
you to immediately verify the URLs listed in the `update.config`_ file.
The Force Immediate Update option disregards the offset hour and
interval set in the `update.config`_ file and immediately updates the
URLs listed.

To configure the Force Immediate Update option

1. Edit the following variables in `records.config`_

   -  `proxy.config.update.force`_
   -  Make sure the variable
      `proxy.config.update.enabled`_ is set to 1.

2. Run the ``command traffic_line -x`` to apply the configuration
   changes.

**IMPORTANT:** When you enable the Force Immediate Update option,
Traffic Server continually updates the URLs specified in the
`update.config`_ file until you disable the option. To disable the
Force Immediate Update option, set the variable
`proxy.config.update.force`_ to ``0`` (zero).

Pushing Content into the Cache
==============================

Traffic Server supports the HTTP ``PUSH`` method of content delivery.
Using HTTP ``PUSH``, you can deliver content directly into the cache
without client requests.

Configuring Traffic Server for PUSH Requests
--------------------------------------------

Before you can deliver content into your cache using HTTP ``PUSH``, you
must configure Traffic Server to accept ``PUSH`` requests.

To configure Traffic Server to accept ``PUSH`` requests

1. Edit `records.config`_, modify the super mask to allow ``PUSH`` request.

   -  `proxy.config.http.quick_filter.mask`_

2. Edit the following variable in `records.config`_, enable
   the push_method.

   -  `proxy.config.http.push_method_enabled`_

3. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Understanding HTTP PUSH
-----------------------

``PUSH`` uses the HTTP 1.1 message format. The body of a ``PUSH``
request contains the response header and response body that you want to
place in the cache. The following is an example of a ``PUSH`` request:

::

    PUSH http://www.company.com HTTP/1.0
    Content-length: 84

    HTTP/1.0 200 OK
    Content-type: text/html
    Content-length: 17

    <HTML>
    a
    </HTML>

**IMPORTANT:** Your header must include ``Content-length`` -
``Content-length`` must include both ``header`` and ``body byte count``.

Tools that will help manage pushing
-----------------------------------

There is a perl script for pushing, `tools/push.pl`_,
which can help you understanding how to write some script for pushing
content.

Pinning Content in the Cache
============================

The **Cache Pinning Option** configures Traffic Server to keep certain
HTTP objects in the cache for a specified time. You can use this option
to ensure that the most popular objects are in cache when needed and to
prevent Traffic Server from deleting important objects. Traffic Server
observes ``Cache-Control`` headers and pins an object in the cache only
if it is indeed cacheable.

To set cache pinning rules

3. Make sure the following variable in `records.config`_ is set

   -  `proxy.config.cache.permit.pinning`_

4. Add a rule in `cache.config`_ for each
   URL you want Traffic Server to pin in the cache. For example:

   ::

       :::text
       url_regex=^https?://(www.)?apache.org/dev/ pin-in-cache=12h

5. Run the command ``traffic_line -x`` to apply the configuration
   changes.

To Cache or Not to Cache?
=========================

When Traffic Server receives a request for a web object that is not in
the cache, it retrieves the object from the origin server and serves it
to the client. At the same time, Traffic Server checks if the object is
cacheable before storing it in its cache to serve future requests.

Caching HTTP Objects
====================

Traffic Server responds to caching directives from clients and origin
servers, as well as directives you specify through configuration options
and files.

Client Directives
-----------------

By default, Traffic Server does *not* cache objects with the following
**request headers**:

-  ``Authorization``: header

-  ``Cache-Control: no-store`` header

-  ``Cache-Control: no-cache`` header

   To configure Traffic Server to ignore the ``Cache-Control: no-cache``
   header, refer to `Configuring Traffic Server to Ignore Client no-cache Headers`_

-  ``Cookie``: header (for text objects)

   By default, Traffic Server caches objects served in response to
   requests that contain cookies (unless the object is text). You can
   configure Traffic Server to not cache cookied content of any type,
   cache all cookied content, or cache cookied content that is of image
   type only. For more information, refer to `Caching Cookied Objects`_.

Configuring Traffic Server to Ignore Client no-cache Headers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, Traffic Server strictly observes client
``Cache-Control: no-cache`` directives. If a requested object contains a
``no-cache`` header, then Traffic Server forwards the request to the
origin server even if it has a fresh copy in cache. You can configure
Traffic Server to ignore client ``no-cache`` directives such that it
ignores ``no-cache`` headers from client requests and serves the object
from its cache.

To configure Traffic Server to ignore client ``no-cache`` headers

3. Edit the following variable in `records.config`_

   -  `proxy.config.cache.ignore_client_no_cache`

4. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Origin Server Directives
------------------------

By default, Traffic Server does *not* cache objects with the following
**response** **headers**:

-  ``Cache-Control: no-store`` header
-  ``Cache-Control: private`` header
-  ``WWW-Authenticate``: header

   To configure Traffic Server to ignore ``WWW-Authenticate`` headers,
   refer to `Configuring Traffic Server to Ignore WWW-Authenticate Headers`_.

-  ``Set-Cookie``: header
-  ``Cache-Control: no-cache`` headers

   To configure Traffic Server to ignore ``no-cache`` headers, refer to
   `Configuring Traffic Server to Ignore Server no-cache Headers`_.

-  ``Expires``: header with value of 0 (zero) or a past date

Configuring Traffic Server to Ignore Server no-cache Headers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, Traffic Server strictly observes ``Cache-Control: no-cache``
directives. A response from an origin server with a ``no-cache`` header
is not stored in the cache and any previous copy of the object in the
cache is removed. If you configure Traffic Server to ignore ``no-cache``
headers, then Traffic Server also ignores ``no-``\ **``store``**
headers. The default behavior of observing ``no-cache`` directives is
appropriate in most cases.

To configure Traffic Server to ignore server ``no-cache`` headers

3. Edit the following variable in `records.config`_

   -  `proxy.config.cache.ignore_server_no_cache`_

4. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Configuring Traffic Server to Ignore WWW-Authenticate Headers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, Traffic Server does not cache objects that contain
``WWW-Authenticate`` response headers. The ``WWW-Authenticate`` header
contains authentication parameters the client uses when preparing the
authentication challenge response to an origin server.

When you configure Traffic Server to ignore origin server
``WWW-Authenticate`` headers, all objects with ``WWW-Authenticate``
headers are stored in the cache for future requests. However, the
default behavior of not caching objects with ``WWW-Authenticate``
headers is appropriate in most cases. Only configure Traffic Server to
ignore server ``WWW-Authenticate`` headers if you are knowledgeable
about HTTP 1.1.

To configure Traffic Server to ignore server ``WWW-Authenticate``
headers

3. Edit the following variable in `records.config`_

   -  `proxy.config.cache.ignore_authentication`_

4. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Configuration Directives
------------------------

In addition to client and origin server directives, Traffic Server
responds to directives you specify through configuration options and
files.

You can configure Traffic Server to do the following:

-  *Not* cache any HTTP objects (refer to `Disabling HTTP Object Caching`_).
-  Cache **dynamic content** - that is, objects with URLs that end in
   **``.asp``** or contain a question mark (**``?``**), semicolon
   (**``;``**), or **``cgi``**. For more information, refer to `Caching Dynamic Content`_.
-  Cache objects served in response to the ``Cookie:`` header (refer to
   `Caching Cookied Objects`_.
-  Observe ``never-cache`` rules in the `cache.config`_ file.

Disabling HTTP Object Caching
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, Traffic Server caches all HTTP objects except those for
which you have set
```never-cache`` <configuration-files/cache.config#action>`_ rules in
the ```cache.config`` <../configuration-files/cache.config>`_ file. You
can disable HTTP object caching so that all HTTP objects are served
directly from the origin server and never cached, as detailed below.

To disable HTTP object caching manually

3. Edit the following variable in `records.config`_

   -  `proxy.config.cache.http`_

4. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Caching Dynamic Content
~~~~~~~~~~~~~~~~~~~~~~~

A URL is considered **dynamic** if it ends in **``.asp``** or contains a
question mark (**``?``**), a semicolon (**``;``**), or **``cgi``**. By
default, Traffic Server caches dynamic content. You can configure the
system to ignore dyanamic looking content, although this is recommended
only if the content is *truely* dyanamic, but fails to advertise so with
appropriate ``Cache-Control`` headers.

To configure Traffic Server's cache behaviour in regard to dynamic
content

3. Edit the following variable in `records.config`_

   -  `proxy.config.http.cache.cache_urls_that_look_dynamic`

4. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Caching Cookied Objects
~~~~~~~~~~~~~~~~~~~~~~~

.. XXX This should be extended to xml as well!

By default, Traffic Server caches objects served in response to requests
that contain cookies. This is true for all types of objects except for
text. Traffic Server does not cache cookied text content because object
headers are stored along with the object, and personalized cookie header
values could be saved with the object. With non-text objects, it is
unlikely that personalized headers are delivered or used.

You can reconfigure Traffic Server to:

-  *Not* cache cookied content of any type.
-  Cache cookied content that is of image type only.
-  Cache all cookied content regardless of type.

To configure how Traffic Server caches cookied content

3. Edit the following variable in `records.config`_

   -  `proxy.config.cache_responses_to_cookies`_

4. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Forcing Object Caching
======================

You can force Traffic Server to cache specific URLs (including dynamic
URLs) for a specified duration, regardless of ``Cache-Control`` response
headers.

To force document caching

1. Add a rule for each URL you want Traffic Server to pin to the cache
   `cache.config`_:

   ::
       url_regex=^https?://(www.)?apache.org/dev/ ttl-in-cache=6h

2. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Caching HTTP Alternates
=======================

Some origin servers answer requests to the same URL with a variety of
objects. The content of these objects can vary widely, according to
whether a server delivers content for different languages, targets
different browsers with different presentation styles, or provides
different document formats (HTML, XML). Different versions of the same
object are termed **alternates** and are cached by Traffic Server based
on ``Vary`` response headers. You can specify additional request and
response headers for specific ``Content-Type``\ s that Traffic Server
will identify as alternates for caching. You can also limit the number
of alternate versions of an object allowed in the cache.

Configuring How Traffic Server Caches Alternates
------------------------------------------------

To configure how Traffic Server caches alternates, follow the steps
below

3. Edit the following variables in `ecords.config`_

   -  `proxy.config.http.cache.enable_default_vary_headers`_
   -  `proxy.config.http.cache.vary_default_text`_
   -  `proxy.config.http.cache.vary_default_images`_
   -  `proxy.config.http.cache.vary_default_other`_

4. Run the command ``traffic_line -x`` to apply the configuration
   changes.

**Note:** If you specify ``Cookie`` as the header field on which to vary
in the above variables, make sure that the variable
`proxy.config.cache.cache_responses_to_cookies`
is set appropriately.

Limiting the Number of Alternates for an Object
-----------------------------------------------

You can limit the number of alternates Traffic Server can cache per
object (the default is 3).

**IMPORTANT:** Large numbers of alternates can affect Traffic Server
cache performance because all alternates have the same URL. Although
Traffic Server can look up the URL in the index very quickly, it must
scan sequentially through available alternates in the object store.

To limit the number of alternates

3. Edit the following variable in `records.config`_ 

   -  `proxy.config.cache.limits.http.max_alts`_

4. Run the command ``traffic_line -x`` to apply the configuration
   changes.

Using Congestion Control
========================

The **Congestion Control** option enables you to configure Traffic
Server to stop forwarding HTTP requests to origin servers when they
become congested. Traffic Server then sends the client a message to
retry the congested origin server later.

To use the **Congestion Control** option, you must perform the following
tasks:

3. Set the following variable in `records.config`_

   -  `proxy.config.http.congestion_control.enabled`_ to ``1``

-  Create rules in the `congestion.config`_ file to specify:
-  which origin servers Traffic Server tracks for congestion
-  the timeouts Traffic Server uses, depending on whether a server is
   congested
-  the page Traffic Server sends to the client when a server becomes
   congested
-  if Traffic Server tracks the origin servers per IP address or per
   hostname

9. Run the command ``traffic_line -x`` to apply the configuration
   changes.


.. List of links
.. _records.config: configuration-files/records.config
.. _cache.config: configuration-files/cache.config
.. _congestion.config: configuration-files/congestion.config
.. _proxy.config.http.congestion_control.enabled: configuration-files/records.config#proxy.config.http.congestion_control.enabled
.. _proxy.config.cache.limits.http.max_alts: configuration-files/records.config#proxy.config.cache.limits.http.max_alts
.. _proxy.config.http.cache.heuristic_lm_factor: configuration-files/records.config#proxy.config.http.cache.heuristic_lm_factor
.. _proxy.config.http.cache.heuristic_min_lifetime: configuration-files/records.config#proxy.config.http.cache.heuristic_min_lifetime
.. _proxy.config.http.cache.heuristic_max_lifetime: configuration-files/records.config#proxy.config.http.cache.heuristic_max_lifetime
.. _proxy.config.http.cache.when_to_revalidate: configuration-files/records.config#proxy.config.http.cache.when_to_revalidate
.. _proxy.config.update.enabled: configuration-files/records.config#proxy.config.update.enabled
.. _proxy.config.update.retry_count: configuration-files/records.config#proxy.config.update.retry_count
.. _proxy.config.update.concurrent_updates: configuration-files/records.config#proxy.config.update.concurrent_updates
.. _proxy.config.update.force: configuration-files/records.config#proxy.config.update.force
.. _proxy.config.http.quick_filter.mask: configuration-files/records.config#proxy.config.http.quick_filter.mask
.. _proxy.config.http.push_method_enabled: configuration-files/records.config#proxy.config.http.push_method_enabled
.. _proxy.config.cache.permit.pinning: configuration-files/records.config#proxy.config.cache.permit.pinning
.. _proxy.config.cache.ignore_server_no_cache: configuration-files/records.config#proxy.config.cache.ignore_server_no_cache
.. _proxy.config.cache.ignore_authentication: configuration-files/records.config#proxy.config.cache.ignore_authentication
.. _proxy.config.cache.http: configuration-files/records.config#proxy.config.cache.http
.. _proxy.config.http.cache.cache_urls_that_look_dynamic: configuration-files/records.config#proxy.config.http.cache.cache_urls_that_look_dynamic
.. _proxy.config.cache_responses_to_cookies: configuration-files/records.config#proxy.config.cache_responses_to_cookies
.. _proxy.config.http.cache.enable_default_vary_headers: configuration-files/records.config#proxy.config.http.cache.enable_default_vary_headers
.. _proxy.config.http.cache.vary_default_text: configuration-files/records.config#proxy.config.http.cache.vary_default_text
.. _proxy.config.http.cache.vary_default_images: configuration-files/records.config#proxy.config.http.cache.vary_default_images
.. _proxy.config.http.cache.vary_default_other: configuration-files/records.config#proxy.config.http.cache.vary_default_other
.. _proxy.config.cache.cache_responses_to_cookies: configuration-files/records.config#proxy.config.cache.cache_responses_to_cookies

.. _tools/push.pl: http://git-wip-us.apache.org/repos/asf?p=trafficserver.git;a=blob;f=tools/push.pl
