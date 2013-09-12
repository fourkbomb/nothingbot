package NothingBot::Plugins::Regexp;
use strict;
use warnings;

my %listeners = (irc_msg => [\&process]);

my $gnick = $::gnick;
sub register {
	&::register_listener_hash(\%listeners);
}

our @disabled = ();

sub process {
	my ($who, $where, $what) = @_;
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];

	print "Got nick: $nick from who: $who\n";	
	print "substitution check - ", $what =~ /^s(\W).*\1/, "\n";
	if ($what =~ /^s(\W).*\1/) {
		my $delimchar = substr($what, 1, 1);
		print "'", join(" ", @disabled), "'\n";
		if (grep { print "$_"; $_ eq $delimchar } @disabled) {
			return 1; # disabled.
		}
		print "$1 - $delimchar - ";
		my $mcounts = () = $what =~ /[^\\]\Q$delimchar\E/;
		print "$mcounts\n";
		THINGY: {
			if ($mcounts < 3) {
				if ($delimchar =~ /[\[\({<]/) {
					my $n = $delimchar eq "[" ? "]" : ($delimchar eq "(" ? ")" : ($delimchar eq "{" ? "}" : ">"));
					my $m2counts = () = $what =~ /[^\\]\Q$n\E/;
					if ($mcounts > 1 and $m2counts < 2) {
						$what .= $n; #$delimchar eq "[" ? "]" : ($delimchar eq "(" ? ")" : ($delimchar eq "{" ? "}" : ">"));
					}
					else {
						last THINGY;
					}
				}
				else {
	
					$what .= $delimchar;
				}
			}
		}
		if (not defined  $::lastmessages{$nick}) {
			$::irc->yield(privmsg => $chan =>  "$nick: you haven't said anything for me to hear.");
		}
		my $newmsg = $::lastmessages{$nick};
		eval "\$newmsg =~ $what";
		if ($@) {
			print $@, "\n";
			#$::irc->yield(privmsg => $chan => "Invalid RE.");
			$::irc->yield(privmsg => $chan =>  "Invalid RE.");
			return 1;
		}
		if ($newmsg eq "") {
			$::irc->yield(privmsg => $chan =>  "$nick said nothing.");
			return 1;
		}
		$::lastmessages{$nick} = $newmsg;
		$::irc->yield(privmsg => $chan =>  "$nick meant $newmsg");
		return 1;
	}
	elsif ($what !~ /^$gnick/ and $what !~ /^\Q$::prefix\E/ and $what !~ /^s(\W).*\1/) {
		print "that's a message.\n";
		$::lastmessages{$nick} = $what;
		return 0;
	}
	elsif ($what =~ /^\Q$::prefix\E/) {
		$what = substr($what, 1);
		if ($what =~ /^regexp/) {
			$what =~ s/regexp//;
			if ($what =~ /^ disable /) {
				$what =~ s/ disable //;
				$what =~ s/ +/ /g;
				$what =~ s/^ +//g;
				print $what, "\n";
				chomp $what;
				my $j = (split(/ /, $what))[0];#substr($what, 1, 1);
				push @disabled, $j;
				$::irc->yield(notice => $nick => "\x02$j\x0f disabled");
			}
			elsif ($what =~ /^ enable /) {
				$what =~ s/^ enable //;
				$what =~ s/ +/ /g;
				$what =~ s/^ +//g;
				chomp $what;
				my $j = (split(/ /, $what))[0]; #substr $what, 1, 1;
				@disabled = grep { $_ ne $j; } @disabled;
				$::irc->yield(notice => $nick => "\x02$j\x0f re-enabled");
			}
			else {
				$::irc->yield(notice => $nick => "${main::prefix}regexp <disable|enable> <char> - allow/block use of <char> as a regexp delimiter");
			}
		}
	}
}

1;
