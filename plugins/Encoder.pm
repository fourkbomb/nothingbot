package NothingBot::Plugins::Encoder;
use strict;
use warnings;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Digest::SHA;
use v5.010;

require 'utils/Colours.pm';

my %subs = (irc_msg => [\&irc_public]);

my @help = (
	"${main::prefix}encode <ARGS> - encode stuff. encode help for more info.",
	"${main::prefix}reverse <TEXT> - reverse TEXT."
);
sub register {
	&::register_listener_hash(\%subs);
	&::register_help_msgs("Encoder", @help);
}

sub encode {
	my $cmd = shift;
	my @args = @_;
	given ($cmd) {
		when ("help") {
			return "encode <sha <num> <text>|md5 <text>|pack <spec> <text>|crypt <text>|rot <amount> <text>";
		}
		when ("sha" or "shasum") {
			my $shaer = Digest::SHA->new(shift @args);
			if (not defined $shaer) {
				return "Bad algorithm.";
			}
			my $text = join(" ", @args);
			$shaer->add($text);
			my $t = "SHA-" . $shaer->algorithm() . " of $text: (base64): " . $shaer->b64digest . " (hex): " . $shaer->hexdigest;
			return $t;
		}
		when ("md5" or "md5sum") {
			my $text = join(" ", @args);
			return "MD5SUM of $text: (base64) " . md5_base64($text) . " (hex) " . md5_hex($text);
		}
		when ("pack") {
			my $pack_spec = shift @args;
			my $text = join(" ", @args);
			eval "pack(\$pack_spec, \@args);";
			if ($@) {
				print $@, "\n";
				return "Invalid pack spec: $pack_spec";
			}
			return "Packed version of $text (using $pack_spec): " . pack($pack_spec, @args);
		}
		when ("crypt") {
			my $salt = shift @args;
			my $text = join(" ", @args);
			return "Crypt'd version of '$text' (using salt '$salt'): " . crypt($text, $salt);
		}
		when ("rot13") {
			my $text = join(" ", @args);
			my $nt = "";
			$nt .= chr(abs((ord($_)+13))) for split//,$text;
			return $nt;
		}
		when ("rot") {
			my $amount = shift @args;
			my $text = join(" ", @args);
			my $nt = "";
			$nt .= chr(abs((ord($_)+$amount))) for split//,$text;
			return $nt;
		}
	}
}

sub handle_msg {
	my ($nick, $who, $what) = @_;

	if ($what =~ /^\Q$::prefix\E/) {
		$what =~ s/^\Q$::prefix\E//;
		my ($cmd, @args) = split(/ /,$what);
		given($cmd) {
			when ("encode") {
				return encode(@args);
			}
			when ("reverse") {
				return reverse join(" ", @args);
			}
		}
	}
}

sub irc_public {
	my ($who, $where, $what) = @_;
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];
	my $msg = handle_msg($nick, $who, $what);
	if (defined $msg and $msg ne "") {
		$::irc->yield(privmsg => $who => $msg);
		return 1;
	}
	return 0;

}
