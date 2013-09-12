package NothingBot::Plugins::Karma;
use strict;
use warnings;

my %listeners = ( irc_msg => [\&handle_chanmsg]);

sub register {
	main::register_listener_hash(\%listeners);
}

my $gnick = $main::gnick;

our %karma = ();

sub handle_chanmsg {
	my ($who, $where, $what) = @_;
	my $nick = (split/!/,$who)[0];

	print "Why hello there! $what\n";
	my $chan = $where->[0];
	if ($nick =~ /bot.$/i or $nick =~ /Serv/i or $nick =~ /^bot/i or $nick =~ /Op$/) {
		print "Bot captur'd\n";
		return 0; # rudimentary bot-capture
	}
	my $diff = 0;
	my @parts = split/ /, $what;
	print "$what =~ /^${main::prefix}karma/\n";
	if ($what =~ /^\Q$::prefix\Ekarma/) {
		shift @parts;
		my $ktarg = shift @parts;
		if (not defined $ktarg) {
			$ktarg = $nick;
		}
		if (not $karma{$ktarg}) {
			$::irc->yield(privmsg => $where => "$nick: $ktarg has no karma.");
		}
		else {
			$::irc->yield(privmsg => $where => "$nick: $ktarg has $karma{$ktarg} karma.");
		}
		return 0;
	}
	
	if ($parts[0] =~ /\+\+$/) {
		$diff = 1;
	}
	elsif ($parts[0] =~ /--$/) {
		$diff = -1;
	}
	else {
		return 0;
	}
	my $targ = shift @parts;
	$targ =~ s/((\+\+)|(--))$//;
	$targ = lc $targ;
	$nick = lc $nick;
	if ($targ eq $nick) {
		$karma{$targ} = $karma{$targ} ? $karma{$targ}-1 : -1; 
		return 1;
	}
	else {
		$karma{$targ} = ($karma{$targ} ? $karma{$targ}+$diff : $diff);
	}
	
}

1;
