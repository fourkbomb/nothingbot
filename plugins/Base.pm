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
	"${prefix}ord <CHAR> - print the ASCII value of CHAR",
	"${prefix}chr <INT> - print the text value of INT",
	"${prefix}authlevel - tells you how authenticated you are",
	"${prefix}cfg - config-related commands. cfg help for more info",
#	"${prefix}register - reload all plugin help, event handlers and command permissions"
);

my %levels = (
	reload => "OWNER",
	restart=> "OWNER",
	register=>"OWNER",
	leave  => "OP",
	cfg	   => "OWNER",
	join   => "OWNER"
);

sub register {
	## Register listeners etc.
	main::register_listener_hash(\%listeners);	
	main::register_help_msgs("Base", @help);
	for (keys %levels) {
		print "$_ => $levels{$_}\n";
		if ($levels{$_} eq "OWNER") {
			&::add_owner_cmd($_);
		}
		elsif ($levels{$_} eq "OP") {
			&::add_op_cmd($_);
		}
	}
	print "Registered.\n";
}

my $gnick = $main::gnick;

sub get_response_for {
	my ($nick, $what, $who, $kernel, $sender, $is_chan, $chan) = @_;
	 $chan = $nick if not defined $chan or $chan eq "";
	if ($what =~ /^$gnick/ and $what =~ /^(hello)|(hi)|(wassup)|(hey)/) {
		print "PRIVMSG $chan Hey there, $nick\n";
		#$kernel->post( $sender => privmsg => $chan => "Hey there, $nick" );
		return "Hey there, $nick!";
	}
	elsif ($what =~ /^s\/.*\/.*\/?.?$/) {
		if ($what !~ /\/.?$/) {
			$what += "/";
		}
		if (not defined  $::lastmessages{$nick}) {
			return "$nick: you haven't said anything for me to hear.";
		}
		my $newmsg = $::lastmessages{$nick};
		eval "\$newmsg =~ $what";
		if ($?) {
			#$kernel->post($sender => privmsg => $chan => "Invalid RE.");
			return "Invalid RE.";
			return;
		}
		if ($newmsg eq "") {
			return "$nick said nothing.";
		}
		$::lastmessages{$nick} = $newmsg;
		return "$nick meant $newmsg";
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
			return "I already know that. Sorry.";
			return;
		}	
		print "MEM: $msg\n";
		push @::memory, $msg;
		return "FYI, $nick, $msg.";
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
			return "$nick: " . (grep(/^$msg/, @::memory))[0] ;
		}
		else {
			return "$nick: i'm clueless about $msg.";
		}
	}

	if ($what =~ /^\Q$::prefix\E/) {
		$what =~ s/^\Q$::prefix\E//;
		my ($cmd,@args) = split/ /,$what;
		if (&::check_can_run($cmd, $who, $chan, $sender->get_heap()) == 0) {
			return "$nick: Access denied.";
		}
		print "prefix!\n";
		given (lc $cmd) {
			when (/^shoo/) {
				$::AWAY = 1;
				$kernel->post($sender => away => "$nick told me to go away.");
				return "$nick: your wish is my command.";
			}
			when (/^comeback/) {
				undef $::AWAY;
				$kernel->post($sender => "away");
				return "$nick asked me to come back, so i did.";
			}
			when (/^act/) {
				if ($args[0] eq 'be') {
					$args[0] = 'is';
				}
				elsif ($args[0] ne 'to' and $args[0] !~ /ing$/ and $args[0] ne '') {
					$args[0] .= 's';
				}
				
				$main::irc->yield(ctcp => $chan => "ACTION " . join(' ', @args));
			}
			when (/^slap/) {
				$main::irc->yield(ctcp => $chan => "ACTION slaps " . join(' ', @args));
			}
			when (/^ord/) {
				print "$nick: $args[0] => ", ord($args[0]); 
				return "$nick: $args[0] => " . ord($args[0]);
			}
			when (/^chr/) {
				return "$nick: $args[0] => " . chr($args[0]);
			}
			when (/^join/) {
				$kernel->post($sender => join => $args[0]);
			}
			when (/^leave/) {
				$kernel->post($sender => part => $args[0]);
			}
			when (/^cfg/) {
				if ($args[0] eq "reload") {
					$kernel->post($sender => privmsg => $chan => "Reloading \x02Config\x02...");
					&::load_config();
					return "Done!";
				}
				else {
					return "config reload - reload config.";
				}
			}
			when (/^register/) {
				print "forcing re-register of all plugins..\n";
				%::handlers = ();
				@::help = ();
				@::opcmds = ();
				@::ownercmds = ();
				$kernel->post($sender => privmsg => $chan => "Reloading command permissions, handlers and help for modules...");
				for (@::modules) {
					"NothingBot::Plugins::$_"->register();
				}
				return "Done!";
			}
			when (/^restart/) {
				$kernel->post($sender => privmsg => $chan => "brb...");
				sleep 2;
				exec($^X, $0, join(' ', @ARGV));
			}
			when (/^reload/) {
				print "reload requested.\n";
				$kernel->post($sender => privmsg => $chan => "Reloading \x02$args[0]\x02...");
				do "plugins/$args[0].pm";
				$kernel->post($sender => privmsg => $chan => "Done!");
				return undef;
			}
			when (/^quit/) {
				print "===STOPPING===\n";
				$kernel->post($sender=>privmsg=>$chan=>"bye all!");
				sleep 1;
				exit;
			}
			when (/^runwho/) {
				$kernel->post($sender=>whois=>$nick);
			}
		}
	}
	return undef;
}

sub handle_chanmsg {
	my ($kernel, $sender, $who, $where, $what) = @_;
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];
	my $poco = $sender->get_heap();
	#print "$nick ($chan): '$what'\n";
	
	if ($what !~ /^$gnick/ and $what !~ /^\Q$::prefix\E/ and $what !~ /^s\/.*\/.*\//) {
		$::lastmessages{$nick} = $what;
	}

	if (defined $::AWAY and $what !~ /^\Q$::prefix\Ecomeback/) {
		return 1;
	}
	#my ($nick, $what, $who, $kernel, $is_chan) = @_;
	my $msg = get_response_for($nick, $what, $who, $kernel, $sender, 1, $chan);
	if (defined $msg) {
		$kernel->post($sender => privmsg => $chan => $msg);
	}
	
	return 0;
}

1;
