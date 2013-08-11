package NothingBot::Plugins::Base;
use strict;
use warnings;
use v5.010;
my %listeners = (irc_msg => [\&handle_chanmsg]);

my $prefix = $::prefix;
my @help = (
	"${prefix}reload <MODULE> - reload module",
	"${prefix}restart - restart NothingBot",
	"${prefix}shoo - make NothingBot go away",
	"${prefix}comeback - make NothingBot come back",
	"${prefix}act <ACTION> - make NothingBot do something (CTCP ACTION)",
	"${prefix}slap <OBJECT> - make NothingBot CTCP ACTION slaps <OBJECT>",
	"${prefix}leave <CHAN> - make NothingBot leave CHAN",
	"${prefix}join <CHAN> - make NothingBot join CHAN",
);

sub register {
	## Register listeners etc.
	main::register_listener_hash(\%listeners);	
	main::register_help_msgs(@help);
	print "Registered.\n";
}

my $gnick = $main::gnick;

sub handle_chanmsg {
	my ($kernel, $sender, $who, $where, $what) = @_;
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];
	my $poco = $sender->get_heap();
	#print "$nick ($chan): '$what'\n";
	if ($what =~ /^$gnick/ and $what =~ /(hello)|(hi)|(wassup)|(hey)/) {
		print "PRIVMSG $chan Hey there, $nick\n";
		$kernel->post( $sender => privmsg => $chan => "Hey there, $nick" );
	}
	elsif ($what =~ /^$gnick help/) {
		$kernel->post( $sender => privmsg => $chan => "Say hi to me, and I'll say hi back." );
	}
	elsif ($what =~ /^s\/.*\/.*\/$/) {
		my $newmsg = $::lastmessages{$nick};
		eval "\$newmsg =~ $what";
		if ($?) {
			$kernel->post($sender => privmsg => $chan => "Invalid RE.");
			return;
		}
		$::lastmessages{$nick} = $newmsg;
		$kernel->post($sender => privmsg => $chan => "$nick meant $newmsg");
	}

	elsif ($what =~ /^$gnick.*, ok\?/) {
		my $msg = $what;
		$msg =~ s/^$gnick.?//g;
		$msg =~ s/, ok\?$//g;
		$msg =~ s/ your / my /ig;
		$msg =~ s/ you/ me /ig;
		$msg =~ s/ (what)|(where)|(when)|(how)|(why)('(s)|(re))? (is)|(are) //ig;
		chomp $msg;
		$msg =~ s/^ +//;
		if (grep(/^$msg/, @::memory)) {
			$kernel->post( $sender=>privmsg=>$chan=>"I already know that. Sorry.");
			return;
		}	
		print "MEM: $msg\n";
		push @::memory, $msg;
		$kernel->post( $sender => privmsg => $chan => "FYI, $nick, $msg." );
	}
	elsif ($what =~ /^$gnick/) {
		my $msg = $what;
		$msg =~ s/^$gnick.?//;
		$msg =~ s/ your / my /ig;
		$msg =~ s/ you / me /ig;
		$msg =~ s/ (what)|(where)|(when)|(how)|(why)('s)? (is)|(are) //ig;
		chomp $msg;
		print "REQ: $msg\n";
		$msg =~ s/^ +//;
		if ($msg =~ /^is m(y|e)/) {
			my $noun = (split/ /, $msg, 3)[2];
			$msg =~ s/is (m(y|e)) .*$/$1 $noun is/;
		}
		$msg =~ s/[^\w\d]$//;
		if (grep(/^$msg/, @::memory)) {
			$kernel->post($sender => privmsg => $chan => "$nick: " . (grep(/^$msg/, @::memory))[0]);
		}
		else {
			$kernel->post($sender => privmsg => $chan => "$nick: i'm clueless about $msg.");
		}
	}

	if ($what =~ /^\Q$::prefix\E/) {
		$what =~ s/^\Q$::prefix\E//;
		my ($cmd,@args) = split/ /,$what;
		given (lc $cmd) {
			when (/^shoo/) {
				$::AWAY = 1;
				$kernel->post($sender => privmsg => $chan => "$nick: your wish is my command.");
				$kernel->post($sender => away => "$nick told me to go away.");
			}
			when (/^comeback/) {
				undef $::AWAY;
				$kernel->post($sender => "away");
				$kernel->post($sender => privmsg => $chan => "$nick asked me to come back, so i did.");
			}
			when (/^act/) {
				if ($args[0] eq 'be') {
					$args[0] = 'is';
				}
				else {
					$args[0] .= 's';
				}
				
				$main::irc->yield(ctcp => $chan => "ACTION " . join(' ', @args));
			}
			when (/^slap/) {
				$main::irc->yield(ctcp => $chan => "ACTION slaps " . join(' ', @args));
			}
			when (/^join/) {
				$kernel->post($sender => join => $args[0]);
			}
			when (/^leave/) {
				$kernel->post($sender => part => $args[0]);
			}
			when (/^restart/) {
				exec($^X, $0, join(' ', @ARGV));
			}
			when (/^reload/) {
				print "reload requested.\n";
				$kernel->post($sender => privmsg => $chan => "Reloading \x02$args[0]\x02...");
				do "plugins/$args[0].pm";
				$kernel->post($sender => privmsg => $chan => "Done!");
			}
		}
	}
	if ($what !~ /^$gnick/ and $what !~ /^\Q$::prefix\E/) {
		$::lastmessages{$nick} = $what;
	}

	return 0;
}

1;
