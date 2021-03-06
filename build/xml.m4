dnl -------------------------------------------------------- -*- autoconf -*-
dnl Licensed to the Apache Software Foundation (ASF) under one or more
dnl contributor license agreements.  See the NOTICE file distributed with
dnl this work for additional information regarding copyright ownership.
dnl The ASF licenses this file to You under the Apache License, Version 2.0
dnl (the "License"); you may not use this file except in compliance with
dnl the License.  You may obtain a copy of the License at
dnl
dnl     http://www.apache.org/licenses/LICENSE-2.0
dnl
dnl Unless required by applicable law or agreed to in writing, software
dnl distributed under the License is distributed on an "AS IS" BASIS,
dnl WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
dnl See the License for the specific language governing permissions and
dnl limitations under the License.

dnl
dnl xml.m4 Trafficserver's Xml autoconf macros
dnl

dnl
dnl TS_CHECK_XML: look for xml libraries and headers
dnl
AC_DEFUN([TS_CHECK_XML], [
  enable_xml=no

  TS_CHECK_XML_EXPAT
  dnl add checks for other varieties of xml here
])
dnl

AC_DEFUN([TS_CHECK_XML_EXPAT], [
enable_expat=no
AC_ARG_WITH(expat, [AC_HELP_STRING([--with-expat=DIR],[use a specific Expat library])],
[
  if test "x$withval" != "xyes" && test "x$withval" != "x"; then
    expat_base_dir="$withval"
    if test "$withval" != "no"; then
      enable_expat=yes
      case "$withval" in
      *":"*)
        expat_include="`echo $withval |sed -e 's/:.*$//'`"
        expat_ldflags="`echo $withval |sed -e 's/^.*://'`"
        AC_MSG_CHECKING(checking for Expat includes in $expat_include libs in $expat_ldflags )
        ;;
      *)
        expat_include="$withval/include"
        expat_ldflags="$withval/lib"
        AC_MSG_CHECKING(checking for Expat includes in $withval)
        ;;
      esac
    fi
  fi
])

if test "x$expat_base_dir" = "x"; then
  AC_MSG_CHECKING([for Expat location])
  AC_CACHE_VAL(ats_cv_expat_dir,[
  _expat_dir_list=""
  case $host_os_def in
    darwin)
    for dir in "`xcrun -show-sdk-path`/usr" /usr/local /usr; do
      if test -d $dir && test -f $dir/include/expat.h; then
        ats_cv_expat_dir=$dir
        break
      fi
    done
    ;;
    *)
    for dir in /usr/local /usr; do
      if test -d $dir && test -f $dir/include/expat.h; then
        ats_cv_expat_dir=$dir
        break
      fi
    done
    ;;
  esac

  unset _expat_dir_list
  ])

  expat_base_dir=$ats_cv_expat_dir
  if test "x$expat_base_dir" = "x"; then
    enable_expat=no
    AC_MSG_RESULT([not found])
  else
    enable_expat=yes
    expat_include="$expat_base_dir/include"
    expat_ldflags="$expat_base_dir/lib"
    AC_MSG_RESULT([${expat_base_dir}])
  fi
else
  if test -d $expat_include && test -d $expat_ldflags && test -f $expat_include/expat.h; then
    AC_MSG_RESULT([ok])
  else
    AC_MSG_RESULT([not found])
  fi
fi

expath=0
if test "$enable_expat" != "no"; then
  saved_ldflags=$LDFLAGS
  saved_cppflags=$CPPFLAGS
  expat_have_headers=0
  expat_have_libs=0
  if test "$expat_base_dir" != "/usr"; then
    TS_ADDTO(CPPFLAGS, [-I${expat_include}])
    TS_ADDTO(LDFLAGS, [-L${expat_ldflags}])
    TS_ADDTO(LIBTOOL_LINK_FLAGS, [-R${expat_ldflags}])
  fi
  AC_SEARCH_LIBS([XML_SetUserData], [expat], [expat_have_libs=1])
  if test "$expat_have_libs" != "0"; then
      TS_FLAG_HEADERS(expat.h, [expat_have_headers=1])
  fi
  if test "$expat_have_headers" != "0"; then
    enable_xml=yes

    AC_SUBST([LIBEXPAT],["-lexpat"])
    AC_DEFINE([HAVE_LIBEXPAT],[1],[Define to 1 if you have Expat library])
  else
    enable_expat=no
    CPPFLAGS=$saved_cppflags
    LDFLAGS=$saved_ldflags
  fi
fi
AC_SUBST(expath)
])
