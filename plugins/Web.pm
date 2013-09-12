package NothingBot::Plugins::Web;
use strict;
use warnings;
use JSON;
use HTTP::Tiny;
use HTML::Entities;
use URI::Escape;
eval "require IO::Socket::SSL";
if ($@) {
	print STDERR "URL shortening is not available. Install the IO::Socket::SSL module to enable.\n";
}
require "utils/Colours.pm";
use v5.010;
my %subs = (irc_msg => [\&irc_public]);

my @help = (
	"${main::prefix}g TERMS - google for TERMS, and show the first result.",
	"${main::prefix}short URL - make URL shorter using goo.gl",
	"${main::prefix}wp TERMS - search Wikipedia for TERMS",
);

sub register {
	&::register_help_msgs("Web", @help);
	&::register_listener_hash(\%subs);
}
# that's right. google chrome right here.
my $USER_AGENT = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.10 Safari/537.36";

sub google {
	if (scalar(@_) < 1) {
		return "Need at least one search term";
	}
	my $oterm = join(' ', @_);
	my $term = uri_escape($oterm);
	$term =~ s/%20/\+/g;
	print "google for term: $term...\n";
	my $res = HTTP::Tiny->new->get("http://ajax.googleapis.com/ajax/services/search/web?q=$term&v=1.0");
	unless ($res->{success}) {
		print "Google failed - errmsg: $res->{status} $res->{reason}\n";
		return "Failed to grab results from google! (error: \x0304$res->{status}\x0f)";
	}
	elsif (not length $res->{content}) {
		print "Google returned zero-length content.\n";
		return "No response from Google.";
	}
	else {
		print "Google succeded - response: $res->{status} $res->{reason}\n";
		my $data = decode_json($res->{content});

		my $sr = $data->{responseData}{results}[0];
		my $url = shorten_url($sr->{url});	
		my $title = $sr->{title};
		$title =~ s#</?b>#$NothingBot::Colours::BOLD#g;
		$title = decode_entities($title);
		my $content = $sr->{content};
		$content =~ s#</?b>#$NothingBot::Colours::BOLD#g;
		$content = decode_entities($content);
		return "Google result for '$NothingBot::Colours::YELLOW\x02$oterm\x02$NothingBot::Colours::NORMAL'" .
		" :: $title :: $content :: $NothingBot::Colours::GREEN$url$NothingBot::Colours::NORMAL";
	}
}

sub shorten_url {
	my $url = shift;
	my $shortened = HTTP::Tiny->new->request('POST', 'https://www.googleapis.com/urlshortener/v1/url', 
			{
				content => '{"longUrl": "' . $url . '"}',
				headers => {"Content-Type" => "application/json"}
			}
	);
	if ($shortened->{success}) {
		$url = decode_json($shortened->{content});
		$url = $url->{id};
	}
	else {
		print "failed to goo.gl $url: $shortened->{status} $shortened->{reason}\n";
		print "content: $shortened->{content}\n";
	}

	return $url;
}

sub wikipedia {
	my $oterm = join(' ', @_);
	my $term = uri_escape(join(' ', @_));
	my $qurl = "http://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=$term&srlimit=1&format=json";
	my $res  = HTTP::Tiny->new(agent => $USER_AGENT)->get($qurl);
	unless ($res->{success}) {
		print "Failed to get wp article $term - $res->{status} $res->{reason}\n";
		return "Request failed - got an error $res->{status}";
	}

	my $json = $res->{content};
	$json = decode_json($json);
	my $hits   = $json->{query}{searchinfo}{totalhits};
	if ($hits == 0) {
		return "Wikipedia results for \x02$oterm\x02 (0 found) ::$NothingBot::Colours::RED No results";
	}
	my $search = $json->{query}{search}[0];
	my $title  = $search->{title};
	my $snippet= $search->{snippet};
	print "'$snippet'\n";
	$snippet =~ s#</?span.*?>#\x02#g;
	$snippet =~ s#\x02 s(\W)#\x02s$1#g;
	$snippet =~ s# s(\W)#s$1#g;
	$snippet =~ s#</?b>#\x02#g;
	$snippet =~ s#  +# #g;
	$snippet =~ s# \x02\.\.\.\x02 ?$##g;
	$snippet =~ s# \. #\. #g;
	my $farticle = $title;
	$farticle =~ s/ /_/g;
	$farticle = "http://en.wikipedia.org/wiki/" . uri_escape($farticle);
	return "Wikipedia results for \x02$oterm\x02 ($hits found) :: $title :: $snippet :: $NothingBot::Colours::GREEN" 
	. shorten_url($farticle);

	
}

sub get_title {
	my $url = shift;
	print "Grab: $url\n";
	my $content = HTTP::Tiny->new(agent => $USER_AGENT)->get($url);
	unless ($content->{success}) {
		print "Failed to get title for $url - $content->{status} $content->{reason}\n";
		print "Content returned: $content->{content}\n";
		return undef;
	}
	else {
		if ($content->{headers}->{"content-type"} !~ m#text/.?html#) {
			my $length = $content->{headers}->{"content-length"};
			if (defined $length) {

				for (qw(bytes KB MB GB TB)) {
					if ($length < 1024) {
						$length = sprintf("%3.1f$_", $length);
						last;
					}
					else {
						$length /= 1024;
					}
				}
			}
			else {
				$length = "Unknown length";
			}
			my $bname = (split(/\//, $url))[-1];
			return "$bname - " . $content->{headers}->{"content-type"} . " - $length";
		}
		else {
			$content->{content} =~ /<title>(.*?)<\/title>/;
			return "Title: " . decode_entities($1);
		}
	}
}
	
	
sub handle_msg {
	my ($nick, $what, $who, $chan) = @_;

			
	if ($what =~ /^\Q$::prefix\E/) {
		$what =~ s/^\Q$::prefix\E//;
		my ($cmd, @args) = split(" ", $what);
		given ($cmd) {
			when ("g") {
				return google(@args);
			}
			when ("short") {
				return "Shortened version of $args[0]: $NothingBot::Colours::RED\x02" . shorten_url($args[0]) .
				"$NothingBot::Colours::NORMAL\x02";
			}
			when ("wp") {
				return wikipedia(@args);
			}
		}
	}
	elsif ($what =~ m`https?://[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@#/%=~_()|]`) {
		my @matches = ($what =~ m`https?://[-A-Za-z0-9+&@#/%?=~_()|!:,.;]*[-A-Za-z0-9+&@#/%=~_()|]`gc);
		for (@matches) {
			$::irc->yield(privmsg => $chan => get_title($_));
		}
	}
	return undef;
}

sub always_false {
	print "Got to " . __LINE__ . " in " . __FILE__ . "!\n";
	return 0;
}


sub irc_public {
	my ($who, $where, $what) = @_;
	my $nick = (split/!/, $who)[0];
	my $msg = handle_msg($nick, $what, $who, $where);
	if (defined $msg) {
		$::irc->yield(privmsg => $where => $msg);
	}
}
