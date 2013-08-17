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
	"${main::prefix}short URL - make URL shorter using goo.gl"
);

sub register {
	&::register_help_msgs("Web", @help);
	&::register_listener_hash(\%subs);
}


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
		return "Failed to grab results from google! (err $res->{status})";
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
	$url = $url;
	if ($shortened->{success}) {
		$url = decode_json($shortened->{content});
		$url = $url->{id};
	}
	else {
		print "failed to goo.gl URL: $shortened->{status} $shortened->{reason}\n";
		print "content: $shortened->{content}\n";
	}

	return $url;
}
	
sub handle_msg {
	my ($nick, $what, $who, $kernel, $sender, $is_chan, $chan) = @_;

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
		}
	}
	return undef;
}



sub irc_public {
	my ($kernel, $sender, $who, $where, $what) = @_;
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];
	my $msg = handle_msg($nick, $what, $who, $kernel, $sender, 1, $chan);
	if (defined $msg) {
		$kernel->post($sender => privmsg => $chan => $msg);
	}
}
