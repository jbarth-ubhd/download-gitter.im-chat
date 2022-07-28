#!/usr/bin/perl
use strict;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);
use JSON::XS;
binmode STDOUT, ":utf8";

my $roomId="5abd2a35d73408ce4f93ac2e";

open my $f, "<", "bearer.txt" or die $!;
my $bearer=<$f>;
close $f;
chomp $bearer;

my @h=("Content-Type", "application/json",
"Accept", "application/json",
"Authorization", "Bearer $bearer");

if($h[5]!~/^Bearer [0-9a-fA-F]{40}$/) { 
  die "Bearer (api-key) (from file: bearer.txt) not well-formed\n";
}

my $ua=LWP::UserAgent->new;
sub getUrl {
  my $url=shift;
  my $resp=$ua->get($url, @h);
  if(!$resp->is_success) { die "error get($url)\n"; }
  return $resp->content;
}
sub getUrlCached {
  my $url=shift;
  my $md5="cache_".md5_hex($url).".json";
  if(-f $md5) { 
    my $t="";
    open my $f, "<", $md5;
    my $t = do { local $/; <$f> };
    close $f;
    return $t;
  }

  my $resp=$ua->get($url, @h);
  if(!$resp->is_success) { die "error get($url)\n"; }
  open my $f, ">", $md5;
  print $f $resp->content;
  close $f;
  return $resp->content;
}


print "<!DOCTYPE html><html><head>
<meta charset='UTF-8'>
<style>
body {
  font-family: Georgia;
  color: #ddd;
  background-color: #000;
}
a { color: #aaf; }
.mention { color:#f88; }
.hd { color:#997; }
.bdy {
  margin-left:25px;
  margin-bottom:10px;
}
.reply {
  border: 0;
  border-left: 1px;
  border-color: #844;
  border-style: dashed;
  margin-left: 15px;
}
code,pre { }
blockquote { background-color: #553; }
.hl { background-color:#844; }
</style><body>\n";

my @mon=qw(xx Jan Feb Mrz Apr Mai Jun Jul Aug Sep Okt Nov Dez);

sub niceDate { my $d=shift;
  my @d=split /\D+/, $d;
#  @d=map { $_=~s/0/o/g; $_ } @d;
  $d[1]=$mon[$d[1]];
  $d[2]=~s/^0//;
  return "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$d[2].$d[1].$d[0] $d[3]:$d[4]";
}

sub formatItem {
  my $item = shift;
  my $json = shift;  # for lookups
  my $extra_class = shift;

  my $tmp = "";

  my $user=$json->{lookups}->{users}->{$item->{fromUser}};
  # "thread" behaviour does not seem to align with the normal message behaviour,
  # fall back to reading the data directly in this case:
  if (not defined $user) {
    $user = $item->{fromUser}
  }

  $tmp.="<div class='message $extra_class'>\n";
  $tmp.="<div class='hd'>".$user->{displayName}." [".$user->{username}."] ".niceDate($item->{sent})."</div>\n";
  # $item->{html}=~s"ocrd[_-]cis"<span class='hl'>ocrd_cis</span>"g;
  # $item->{html}=~s"ocrd[_-]segment"<span class='hl'>ocrd_segment</span>"g;
  # $item->{html}=~s"ocrd[_-]any"<span class='hl'>ocrd_any</span>"g;
  # $item->{html}=~s"ocrd[_-]pc[_-]segment"<span class='hl'>ocrd_pc_segment</span>"g;
  # $item->{html}=~s"sbb[_-]textline"<span class='hl'>sbb_textline</span>"g;
  $tmp.="<div class='bdy'>".$item->{html}."</div>\n";
  $tmp.="</div>\n";

  return $tmp;
}

my $baseUrl="https://gitter.im/api/v1/rooms/$roomId/chatMessages?lookups%5B%5D=user&limit=100";
my $topId="";
my $html="";
for(my $i=0; $i<999; $i++) {
  my $url=$baseUrl.(length($topId)?"&beforeId=$topId":"");
  print STDERR "get $url\n";
  my $json=decode_json(getUrlCached($url));

  if(ref($json) ne "HASH") {
    print $html;
    print "</body></html>\n";
    exit;
  }

  my $tmp = "";
  for my $item (@{$json->{items}}) {
    $tmp .= formatItem($item, $json);

    # Retrieve thread if necessary
    if ($item->{threadMessageCount} >= 1) {
      my $chatId = $item->{id};
      my $threadUrl="https://gitter.im/api/v1/rooms/$roomId/chatMessages/$chatId/thread?lookups%5B%5D=user";
      # Retrieving uncached as the thread may have changed since the last run,
      # and we have no way of invalidating the cache.
      print STDERR "get $threadUrl (uncached)\n";
      my $thread_json = decode_json(getUrl($threadUrl));
      for my $thread_item (@{$thread_json}) {
        $tmp .= formatItem($thread_item, $json, "reply");
      }
    }
  }
  $html=$tmp.$html;

  $topId=$json->{items}->[0]->{id};
}
die "for(my \$i...) limit not high enough\n";
