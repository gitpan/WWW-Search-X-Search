#!perl -w
# X-Search.pl
# $Id: X-Search.PL,v 1.03 2000/06/04 14:58:54 jims Exp $
# (c) Copyright 2000 by Jim Smyser All Rights Reserved

use Cwd;
my $dir = cwd;


## DEFINE USER SETTINGS
# Details can be found in the doc's at end of this script or man pages

$verbose = "1"; # print messages to screen 1=yes print messages 0=No
$ck_url = "0"; # verify if urls are good or not
$iDIR = "$dir/index"; # directory name to store index.html 
$print_summaries = "1"; # 1= print summaries 0= no summaries
$oURLS = "urls.dat"; # our seen urls file
$qconfig = "query.ini"; # the configuration file name & location
$port = "";
$host = "";
$sTEMP = "TEMP";

## END USER SETTINGS
#########################################################################

# Use the configuration file specified from a command line 
# argument if defined by the user

if (defined($ARGV[0])) {
$qconfig = $ARGV[0];
}

$VERSION = '1.03';
use WWW::Search;
use LWP::Simple;
use POSIX qw(strftime);
$now = &time_now;
$today = &date_today;
             
&check_files; # make sure we have what we need

open(LOG, ">$sTEMP");   # to manage our index summary. Perhaps hash it?

print "Script started at $now\n" if ($verbose);
&read_config_file;
foreach $qs (@input) {
($engine,$search_name,$query,$options,$max,$qid) = split (/\|/, $qs);

    # Process any user defined search options 
    foreach my $so (split(/&/, $options)) {
    $so = $so . "\n";
    push(@options, $so);
    }

 if (defined($options)) {
     $query_options = {};
      foreach my $sPair (@options) 
      {
    my ($key, $value) = $sPair =~ m/^([^=]+)=(.*)$/;
    &add_to_hash($key, &WWW::Search::escape_query($value), $query_options);
    }
    }

print "Searching $search_name using $engine\n" if ($verbose);
print LOG "<h3>Summary Results for $search_name</h3>\n" if ($print_summaries eq "1");

&do_search;

print LOG "$iHTML\n" if ($print_summaries);
print LOG "<h3>Detailed Search Results by Date for $search_name</h3><p>\n";
$iHTML = '';
&build_date_links;
} # for ea $qs
&finish_up;
$ftime = &time_now;
print "Script Finished at $ftime\n" if ($verbose);

exit 0;


# The 3 Subs below control the apperance of your web pages.
# The HTML can be edited to your preferences.
######################################################
sub print_ihead {

# This inserts HTML into the index.html file
$ihead = ("
<html>
<head>
<title>Index of X-Search Results</title>
</head>
<BODY>
<br>
<h2>Current Search's being Tracked by X-Search</h2>
<hr><p>
<blockquote>
");
return $ihead;
}

######################################################
sub print_dhead {

# This is our custom head we can print for the dated saved
# results. You can edit the head all you want, just leave
# the <!--#$today--> comment tag alone!

$dhead = ("
<!--#$today-->
<html>
<head>
<title>Search results for: $query</title>
</head>
<BODY>
<br>
<h2>$search_name</h2><br>
<hr><p>
<blockquote>
<h3> Detailed Search Results for $now</h3><p>\n"
);
return $dhead;
}

######################################################
sub print_footer {

# Prints a footer to our pages.  My Version and Email line
# should be left in place. You may edit anything else.

$footer = ("
<br>
<hr>
<font color=green size=2><center>X-Search $VERSION by <a href=\"mailto:jsmyser\@bigfoot.com\">Jim Smyser</a>
</body>
</html>
");
return $footer;
}

# End of HTML display subs


###################################################
sub time_now {
    return strftime("%m/%d/%Y %H:%M:%S", localtime(time));
}

###################################################
sub date_today {
    return strftime("%b %d, %Y", localtime(time));
}

###################################################
sub file_time_stamp {
    return strftime("%Y%m%d", localtime(time));
}


######################################################
sub do_search {

$max= "100" if (!$max); # set a default in the event no max was defined

# Load stored url's we have already seen
open(OLD, $oURLS) || die "$oURLS failed to be opened: $!\n"; 
while(<OLD>) { 
    $old{$_}++; # store in hash key cuz I may have future ideas for using it
push(@old, $_);
} 
close(OLD); 

# record any new urls we haven't seen before to our dat file
open(URLS, ">>$oURLS");


 my $search = new WWW::Search($engine);

  $search->{_host} = $host if defined($host);
  $search->{_port} = $port if defined($port);
  $search->http_proxy($ENV{'HTTP_PROXY'}) if ($ENV{'HTTP_PROXY'});
  $search->http_proxy($ENV{'http_proxy'}) if ($ENV{'http_proxy'});
  $search->native_query(WWW::Search::escape_query($query), $query_options);

  $search->maximum_to_retrieve($max); 

      while (my $result = $search->next_result()) { 
    $url = $result->url;
    $title = $result->title;
    $desc = $result->description;
    # because dejanews returns different baseurl's for the same page
    # from subsequent searches we need to force a consistent baseurl 
    # or we will end up printing the same results over and over.
    # this may well be the case for some other news sources as well 
    $url =~ s/x\d+\.deja.com/x62.deja.com/g; # deja url hack 
    $url =~ s/CONTEXT=.*?&hitnum=.*?&//g; # Don't need this in the deja url, saves space 
    # ?'s and +'s can be problematic
    $url =~ s/\?/%3F/g; # gotta escape those '?'s'  
    $url =~ s/\+/%2B/g; # do +'s too  
    if ($url) {
    foreach $oline (@old) {
    $url = '' if ($oline =~ m/$url/i);
    }
    }
    &head_check if ($ck_url);

    print URLS "$url\n" if ($url ne ''); # record what we have not seen before
    # next line we print to our dateXXXX.html file
    $desc = "(No Description)\n" if (!$desc);
    $url =~ s/%3F/\?/g; # unescape those '?''s  
    $url =~ s/%2B/\+/g;    
    $dHTML .= "<a href=\"$url\">$title</a><br>$desc<p>\n" if ($url ne '');
    # next line we use to print to our main index.html (Summary)
    $iHTML .= " <a href=\"$url\">$title</a><br>\n" if ($url ne '');
    }
    $iHTML = "No Summary for Most Recent Search\n" if (!$iHTML);
    &check_date_file; 
    $query_options = ''; 
} # end do_search


######################################################
sub head_check {

# verify if a given url is good or bad (optional)
return if ($url eq ''); # Don't bother, already seen it
if (head($url)) {
     print "URL is GOOD\n" if ($verbose);
     } else {
     print "$url is BAD\n" if ($verbose);
     print URLS "$url\n";   # make sure we record the bad url
     $url = ''; # get rid of it
     }
return;
}

###############################################################
sub check_date_file {

  # here is where we build our dated search results files
  # that we are tracking over time
  print "No new results for: $search_name\n" if (!$dHTML && $verbose);

  return if (!$dHTML);
  print "Writing results for: $search_name\n" if ($verbose);
  my($file) = (&file_time_stamp).'.html';
  if (open (DATE,'<'."$iDIR/$qid/$file") ) { 
    # it exists
    close (DATE);
    } else { 
    # nope it does not exists
    if (mkdir ("$iDIR/$qid", 0755) ) {
    if ($! =~ m/file exists/i) { # already done
     die "Can't create directory $iDIR.\nReason $!";
      }
      }
    chmod 0755, "$iDIR/$qid" || die "Can't chmod directory $iDIR/$qid.\nReason $!";
      open (HTML,'>'."$iDIR/$qid/$file") || die "Can't open $file.\nReason: $!\n";
      print HTML print_dhead($dhead);
      print HTML "$dHTML"; # print new html: newest search results on top
      print HTML print_footer($footer); # print a new footer
      close (HTML);
      $dHTML = '';
      goto DONE;
      }

      # if the file already exists for the date we will attempt to append
      # new results to it....
  if (-e "$iDIR/$qid/$file") { # file exists: append it
      open (HTML,'<'."$iDIR/$qid/$file") || die "Can't open $file line 195. Reason: $!\n";
      @html = <HTML>;
      close (HTML);
      foreach $line (@html) {
      # We are only interested in our links here
      # You should update this if you print fancier links
      $cHTML .= $1 if ($line =~ m@(<a href=".*?">.*?<p>)@i);
      $cHTML = $cHTML."\n" if ($cHTML);
      $cHTML =~ s/^\s+//g if ($cHTML);
      }
      close (HTML);
      open (HTML,'>'."$iDIR/$qid/$file") || die "Can't open $file.\nReason: $!\n";
      print HTML print_dhead($dhead);
      print HTML "$dHTML"; # print new html: newest search results on top
      print HTML "$cHTML"; # print the current html links back
      print HTML print_footer($footer); # print a new footer
      close (HTML);
      $cHTML = '';
      $dHTML = '';
    } else {
    # create one
      open (HTML,'>'."$iDIR/$qid/$file") || die "Can't open $file. Reason: $!\n";
      print HTML print_dhead($dhead);
      print HTML "$dHTML"; # print new html: newest search results append
      print HTML print_footer($footer);
     close(HTML);
     $dHTML = '';
}
DONE:
}

############################################
sub build_date_links {

# Basically I am just reading the $qid directory and getting
# a list of existing file names and etracting the date from the
# comment tag to build links with and copying saving that data to 
# my temp file for later. Will only build links for active searches.

$qdir = "$iDIR/$qid/";
opendir (DIR, $qdir) || die $!;
@datfiles = grep !/^\.\.?$/, readdir(DIR);
closedir (DIR);
foreach $dfile (@datfiles) {
      $datpath = $qdir . $dfile;
      open (FILE, $datpath);
      @datfile = <FILE>;
      close (FILE);
      foreach $datline (@datfile) {
$fdate = $1 if ($datline =~ m@^<!--#(.*)-->@i);
} # for each data file
$fdate = "Search Results for: <a href=\"./$qid/$dfile\">$fdate</a><br>\n" if (defined($fdate));
push(@dated_files, $fdate) if (defined($fdate));;
$fdate = '';
}
print LOG reverse sort(@dated_files);
undef @dated_files;
return;
}

###############################################################
sub check_files {

# just a dumb sub to make sure we have some files needed to work
# with and they have read/write permissions

 if (open (URLS,'<'."$oURLS") ) { 
    # Looks like it exists
    close (URLS);
    } else { # make a file.
    open (URLS,'>'."$oURLS");
    close(URLS);
    # Ok we have one now!
    }
# check to make sure we can read/write to the temp file we
# use for building the index.html

 if (open (TEMP,'<'."$sTEMP") ) { 
    # Looks like it exists
    close (TEMP);
    } else { # make a file.
    open (TEMP,'>'."$sTEMP");
    close(TEMP);
    # Ok we have one now!
    }
#Check to see if we have a index.html file

 if (open (INDEX,'<'."$iDIR/index.html") ) { 
     # Looks like it exists
     close (INDEX);
     } else { 
     # better make one
     if (mkdir ($iDIR, 0755) ) {
     if ($! =~ m/file exists/i) { # already done
     die "Can't create directory $iDIR.\nReason $!";
    }
    }
    chmod 0755, $iDIR || die "Can't chmod directory $iDIR.\nReason $!";
    }
return;
}

######################################################
sub finish_up {

# Basically just close some files and write a new index.html 
# and were done

close(URLS);
close(LOG);

open (TEMP,'<'."$sTEMP") || die "Can't open TEMP. Reason: $!\n";
@html = <TEMP>;
close (TEMP);
foreach $line (@html) {
$sHTML .= $1 if ($line =~ m@(.*)@i);
$sHTML = $sHTML."\n";
$sHTML =~ s/^\s+//g;
}

open (INDEX,'>'."$iDIR/index.html") || die "Can't create index.html in $iDIR: $!";
print INDEX print_ihead($ihead);
print INDEX "\n";
print INDEX "$sHTML";
print INDEX print_footer($footer);
close(INDEX);
$sHTML = '';
}

######################################################
sub read_config_file {

open (PATH, "$qconfig") || die 
"We need a configuration file with defined search commands. No search commands read!. $!";

@datfile = <PATH>;
close (PATH);
foreach $datline (@datfile) {
if ($datline =~ m@^(\w+.*)$@i) {
$ds = $1;
push(@input, $ds);
}
}
return(@input);
}

######################################################
sub add_to_hash
  {
  # This is a bit of a hack.  A set of CGI options is not strictly a
  # hash, because multiple values for the same key can be specified.
  # To get around this, we rely on the fact that this hash of options
  # is only used to construct a CGI parameter list.  If we see
  # multiple values for the same key, we append the multiple values
  # onto the value of the key in CGI '?key=value' format.
  my ($key, $value, $hashref) = @_;
  if (exists($hashref->{$key}) && $hashref->{$key} ne '')
    {
    # There was already an option of this key given; append
    # multiple values as CGI arguments:
    $hashref->{$key} .= "&$key=$value";
    } # if exists
  else
    {
    # This is the only instance of this key; just insert the
    # hash value:
    $hashref->{$key} = $value;
    }
  } # add_to_hash


=head1 NAME

X-Search -- Automated Web Searching and Search History Indexing

=head1 SYNOPSIS

I<X-Search [optional configuration file name/path argument]>

Search commands are read from a configuration file.

=head1 DESCRIPTION

I<X-Search> reads a series of search commands from a plain text
configuration file and then retrieves the results from the specified
search engine and stores them in individule dated files
F<qid/YYYYMMDD.html> which is a detailed web page record of the search
results for the days date. Summaries of each search (if you have print
summaries turned on) as well as a link history to each
F<qid/YYYYMMDD.html> file are maintained in one F<index.html> file.

Any new search results for a 24 hour perioud are written to both the 
F<qid/YYYYMMDD.html> and F<index.html> files. If F<qid/YYYYMMDD.html> 
already exists with previous search results for the date then it will be
appended with newer results in a chronological order. If there is nothing new
then nothing is written. 

I<X-Search> stores the url's from search results to a data file enabling 
it to track what it already has seen. This insures subsequent searches are
unique and allows one to copy additional undesirable urls in blocks to this
file to prevent X-Search from recording them if they are ever encountered 
in a future search. 

I<X-Search> is ideal for maintaining records of frequent news events and
can safely be run as many times as desired daily to determine new news
events to index that matches the users search requirements. For
instance: You could track any number of newsgroups three times daily for
new posts by passing the search option "groups=". So, in the option
field in the configuration file you could insert |groups=alt.some.group|
or, if you wanted to search all groups related to perl you could do
this: |groups=*perl*|

I<X-Search> Allows the option of verifying the url address to determine if
it is valid or not. Any url's that are found not valid, i.e., moved, not
found, are ignored.

I<X-Search> allows one with a lot of flexibility to use in all sorts of
neat applications.

=head1 CONFIGURATION FILE

I<X-Search> is controled by a configuration file. This file can be
any name you want. There are two methods to tell I<X-Search> what
configuration file to use and where. 

Method 1: Simply define $qconfig in the script to point to the
configuration file. By default it looks for a file called "query.ini"
located in same directory as X-Search. 

Method 2: Command line argument defining path and name of the
configuration file. Example:

X-Search /home/xsearch/search.conf

I<X-Search> would read /home/xsearch/search.conf for it's search commands.
This allows easily using multi configuration files for different search
setups.


This file is read to get the following user defined search
commands:

  1) The search engine to use
  2) A nice Name to describe the top of the search to
     printed on the web pages (Like AutoSearch $query_name)
  3) The query words for the search seperated by a space
  4) Any search options to pass to search engine. This is optional 
     and can be left blank.
  5) Max results to return
  6) The B<qid>, query information directory, the directory name 
     to create to store dated web pages creadted from the search.

A typical configuration file would have one or more lines that
follow this structure:

SEARCH ENGINE|SEARCH NAME|SEARCH WORDS|OPTIONS|MAX_TO_RETURN|QID|

The individule values are seperated with a | and a | must be found
at the end of each line. There is no limit to how many searches you
can define in the configuration file, but you may want to keep it
resonable and to aid in managing multi searches, there is the 
option of turning off/on summaries being displayed in B<index.html>.

Here is a sample of what a typical configuration file should
look like:

------cut------------------

HotBot|Military|tank armor|RD=DM&Domain=.mil|40|tanks|
Google|Tech News|parallel processing||200|parallel| 
Excite::News|News From Home|Palm Springs California||100|myhome|
AltaVista|AZ Fishing|arizona lakes||60|lakes|

--------end-----------------

The Google command line would search the engine Google, print a 
nice list heading titled "Tech News", search and display results
pertaining to "parallel processing", with no options, return a max
of 200 results and store the dated search history pages in a directory
called "parallel".

Obiviously, you want to define different qid names for all your different 
searches so that hot dog searches don't end up mixed with apple searches.

Note About Options

Multiply option pairs must be seperated with '&'. See HotBot search
example above.

=head1 AUTO SEARCHING

X-Search can be run from a cron job to automate searching even more.

Example to run X-Search each Monday at 3:00 AM:

    0 3 * * 1 /home/xsearch/X-Search

or if you want to specify a configuration file:

    0 3 * * 1 /home/xsearch/X-Search /home/xsearch/cofig.conf

=head1 CHANGING THE APPERANCE OF THE WEB PAGES

I<X-Search> web pages are easily customizable by simply changing the html
in the subs "print_ihead" and "print_dhead". The sub print_idead produces
the html for the index.html file. You can add whatever body tags you
desire like background colors, images, fonts, etc. The sub print_dhead
controls the html that goes into F<qid/YYYYMMDD.html> files. 

There is also a "print_footer" sub that prints a footer for all the
pages, and I ask that my name and e-mail address remain intact if you
decide to customize the footer as well. (Publicity is my only payment
from this :-)

=head1 USER SETTINGS

There is a number of user settings that control the behavior of X-Search
which is hard coded into the script.

=item $verbose

This just prints messages to screen while the script is running. This is
nice for manual operation but not needed if run by cron. 

=item $ck_url   

$ck_url = "1";

$ck_url will verify if url's are good or bad. 0=No 1=Yes Setting $ck_url
can slow the search down depending on how many bad urls are encountered.

=item $iDIR

$iDIR = "$dir/index";  

Define a sub-directory name that will store the main index.html file.
The name "index" should be just fine. B<qid> directories will be created
below this directory.
 
=item $print_summaries

$print_summaries = "0";

1=Yes 0=No

If you have many search events defined and running you may want to turn
off printing summary results to keep the index.html file size within
reason. Only links to the detailed F<qid/YYYYMMDD.html> pages will be
printed. Turn it on if you want summaries to be displayed in index.html

=item $oURLS

$oURLS = "urls.dat";

Define the name of our url's record file. Without this we are lost.

=item $qconfig

$qconfig = "query.ini"; 

Define path and name of the query configuration file. This file stores
the search command, such as engines to use, search string, qid
directory, max to return and so forth. SEE bottom of this script for
more details. You MAY also pass this value as a arugument so you can run
multi configuration files

=item $host $port
 
$port = "";
$host = "";

Define a host/port if required (most don't need to)

=item $sTEMP

$sTEMP = "TEMP";

This just defines a name for temporary working file X-Search uses to
build a index.html file. No need to mess with it.

=head1 CHANGES

Version 1.03

 - Created a hack to track Dejanews articles properly
 - added escaping and unescaping ?'s in urls because 
   they would raise havoc with my regex leading to urls
   being printed over and over

=head1 AUTHOR

X-Search was written entierly by Jim Smyser 
E<jsmyser@bigfoot.com>.

=head1 BUGS

Shouldn't be any... but you never know! Report them to me.

=head1 COPYRIGHT

Copyright (c) 2000 by Jim Smyser All rights reserved.                                            
                                                               
You my use this program source provided that the above copyright notice
and this paragraph are duplicated in all such forms and that any
documentation, advertising materials, and other materials related to
your distribution of this source code and use acknowledge Jim Smyser as
the author/developer. 

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.




