package NothingBot::Plugins::Joke;
use strict;
use warnings;

my %jokes = ();

my %next_msg_is_joke = ();

my %listeners = ( irc_msg => [\&handle_chanmsg], irc_ctcp_action => [\&handle_action] );

sub register {
	main::register_listener_hash(\%listeners);
}

my $gnick = $main::gnick;

sub handle_action {
	print "Got that.\n";
	my ($sender, $towhom, $what) = @_;
	$towhom = @{$_[1]}[0];
	print join(', ', @{$_[1]}), ': ';
	print "$what\n";
	my $nick = (split/!/,$sender)[0];
	my $targ = $nick;
	if ($towhom =~ /^#/) {
		$targ = $towhom;
	}
	if ($what =~ /((slap)|(hit)|(wham)|(hate)|(eat)|(pie)|(punche)|(kick))s.*$gnick.*$/) {
		$::irc->yield(privmsg => $targ => "$nick: ouch!");
	}
	return 0;
}

sub handle_chanmsg {
	my ($who, $where, $what) = @_;
	my $nick = (split/!/,$who)[0];
	my $chan = $where->[0];
	if ($next_msg_is_joke{$nick} and $next_msg_is_joke{$nick} == 1) {
		my @parts = split/( because )|(\? )/,$what,2;
		$jokes{$parts[0]} = $parts[1];
		$::irc->yield(privmsg => $chan => "$nick: Very funny!");
		return;
	}


	if ($what =~ /^$gnick,? /) {
		print "dected nick\n";
		$what =~ s/^$gnick,? //;
		if ($what =~ /^here('s)|( is) a joke.?/) {
			$what =~ s/^here('s)|( is) a joke.?//;
			if ($what =~ /^[^\w\d]+$/) {
				$next_msg_is_joke{$nick} = 1;
			}
			else {
				my @parts = split/ because /, $what;
				$jokes{$parts[0]} = $parts[1];
				$::irc->yield(privmsg => $chan => "$nick: Very funny!");
			}
			return;
		}

		$what =~ s/\?\s*$//;
		print "grep $what, ", join(' ', keys %jokes), "\n";
		if (grep(/^$what/,keys %jokes)) {
			$::irc->yield(privmsg => $chan => "$nick: $jokes{$what}");
		}
	}
}

1;
