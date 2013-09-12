package NothingBot::Plugins::Base;
use strict;
use warnings;
use v5.010;
use Symbol qw(delete_package);
my %listeners = (irc_msg => [\&handle_chanmsg]);

my %ops = ();

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
	"${prefix}eval - evalute perl code",
#	"${prefix}register - reload all plugin help, event handlers and command permissions"
);

my %levels = (
	comeback=>"OP",
	reload => "OWNER",
	restart=> "OWNER",
	register=>"OWNER",
	leave  => "OP",
	cfg	   => "OWNER",
	join   => "OWNER",
	eval   => "OWNER",
	op	   => "OP",
	deop   => "OP",
	kick   => "OP",
	unload => "OWNER",
	load   => "OWNER",
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
our $FACTOIDS_DISABLED = 0;

sub get_response_for {
	my ($nick, $what, $who, $where) = @_;
	my $chan = $where;
	 $chan = $nick if not defined $chan or $chan eq "";
#	if ($what =~ /^$gnick/ and $what =~ /^$gnick.? (hello)|(hi)|(wassup)|(hey)/) {
#		print "PRIVMSG $chan Hey there, $nick\n";
#		#$kernel->post( $sender => privmsg => $chan => "Hey there, $nick" );
#		return "Hey there, $nick!";
#	}
	print $FACTOIDS_DISABLED, "\n";	

	if ($what =~ /^$gnick.*, ok\?/ and $FACTOIDS_DISABLED != 1) {
		my $msg = $what;
		$msg =~ s/^$gnick.?//g;
		$msg =~ s/, ok\?$//g;
		$msg =~ s/ your / my /ig;
		$msg =~ s/ you/ me /ig;
		$msg =~ s/ (what)|(where)|(when)|(how)|(why)('(s)|(re))? (is)|(are) //ig;
		chomp $msg;
		my $omsg = $msg;
#		$msg =~ s/ is //g;
#		$msg =~ s/ are //g;
		$msg =~ s/^ +//;
		$omsg =~ s/ +/ /;
		$omsg =~ s/^ +//;
		if (grep(/^$msg/, @::memory)) {
			return "I already know that. Sorry.";
			return;
		}	
		print "MEM: $msg\n";
		push @::memory, $msg;
		return "FYI, $nick, $omsg.";
	}
	elsif ($what =~ /^$gnick/ and $FACTOIDS_DISABLED != 1) {
		my $msg = $what;
		$msg =~ s/^$gnick.?//;
		$msg =~ s/ your / my /ig;
		$msg =~ s/ you / me /ig;
		my $omsg = $msg;
		$omsg =~ s/ +/ /g;
		$msg =~ s/ (what)|(where)|(when)|(how)|(why)('s)? ((is)|(are))? //ig;
		chomp $msg;
		print "REQ: $msg\n";
		$msg =~ s/^ +//;
		if ($msg =~ /^is m(y|e)/) {
			my $noun = (split/ /, $msg, 3)[2];
			$msg =~ s/is (m(y|e)) .*$/$1 $noun is/;
		}
		$msg =~ s/(^| )is //g;
		$msg =~ s/(^| )are //g;
		$msg =~ s/[^\w\d]$//;
		if (grep(/^$msg/, @::memory)) {
			return "$nick: " . (grep(/^$msg/, @::memory))[0] ;
		}
		else {
			return "$nick: i'm clueless about $omsg.";
		}
	}

	if ($what =~ /^\Q$::prefix\E/) {
		$what =~ s/^\Q$::prefix\E//;
		my ($cmd,@args) = split/ /,$what;
		given (lc $cmd) {
			when (/^shoo/) {
				$::AWAY = 1;
				$::irc->yield(away => "$nick told me to go away.");
				return "$nick: your wish is my command.";
			}
			when (/^comeback/) {
				undef $::AWAY;
				$::irc->yield("away");
				return "$nick asked me to come back, so i did.";
			}
			when (/^op/) {
				$::irc->yield("mode" => $chan => '+o' => ($args[0] or $nick));
				return;
			}
			when (/^deop/) {
				$::irc->yield("mode" => $chan => '-o' => ($args[0] or $nick));
				return;
			}
			when (/^kick/) {
				print "kick $chan $args[0]\n";
				my $n = shift @args;
				$main::irc->yield(kick => $chan => $n => join(' ', @args));
				return;
			}
			when (/^act/) {
				my $targ = $chan;
				if ($args[0] =~ /^#/) {
					$targ = shift @args;
				}
				if ($args[0] eq 'be') {
					$args[0] = 'is';
				}
				elsif ($args[0] ne 'to' and $args[0] !~ /ing$/ and $args[0] ne '') {
					$args[0] .= 's';
				}
				
				$main::irc->yield(ctcp => $targ => "ACTION " . join(' ', @args));
			}
			when (/^say/) {
				my $targ = $where;
				if ($args[0] =~ /^#/) {
					$targ = shift @args;
				}
				$main::irc->yield(privmsg => $targ => join(" ", @args));
			}
			when (/^base/) {
				print "base ";
				
				$what =~ s/^base //;
				chomp $what;
				if ($what =~ /^disable /) {
					print "disable ";
					$what =~ s/^disable //;
					if ($what =~ /^factoids/) {
						print "factoids!";
						$FACTOIDS_DISABLED = 1;
					}
				}
				elsif ($what =~ /^enable /) {
					print "enable ";
					$what =~ s/^enable //;
					if ($what =~ /^factoids/) {
						print "factoids!";
						$FACTOIDS_DISABLED = 0;
					}
				}
				print "\n";
			}
			when (/^colou?rs/) {
				my $str = "Colours: ";
				for (my $i = 0; $i < 16; $i++) {
					print "\\x03$i $i\\x0f";
					$str .= "\x03$i $i\x0f";
				}
				$main::irc->yield(privmsg => $chan => $str);
			}
			when (/^modules/) {
				my @loaded = ();
				my @unloaded = ();
				my @failed = ();
				for (keys %::module_states) {
					my @parts = split(/::/, $_, 3);
					if ($::module_states{$_} ne "SUCCESS") {
						push @failed, $parts[2];
					}
					else {
						push @loaded, $parts[2];
					}
				}

				for my $z (@::unloaded) {
					my @parts = split(/::/, $z, 3);
					push @unloaded, $parts[2];
					@loaded = grep {$_ ne $parts[2]} @loaded; 
				}
				
				for my $z (@failed) {
					@unloaded = grep {$_ ne $z} @unloaded;
				}
				print(join(', ', @loaded), " ", join(', ', @failed), " ", join(', ', @unloaded));	
				if ($#loaded < 0) {
					push @loaded, "No modules loaded";
				}
				if ($#unloaded < 0) {
					push @unloaded, "No modules unloaded";
				}
				if ($#failed < 0) {
					push @failed, "No modules failed to load";
				}
				$main::irc->yield(notice => $nick => "\x0303Loaded\x0f: \x02" . join(', ', @loaded) . "\x0f");
				$main::irc->yield(notice => $nick => "\x0304Failed to load\x0f: \x02" . join(', ', @failed));
				$main::irc->yield(notice => $nick => "\x0308Unloaded\x0f: \x02" . join(', ', @unloaded));
			}
			when (/^eval/) {
				my $eval = "use strict; use warnings; " . join(' ', @args);
				my $stdout = "";
				my $stderr = "";
				my $text = "";
				{
					local *STDOUT;
					local *STDERR;

					open STDOUT, ">", \$stdout;
					open STDERR, ">", \$stderr;
					$text = eval $eval;
				}
				$stdout =~ s/\n/ /g;
				$stdout =~ s/\s+$//;
				$stdout =~ s/\s+/ /g;
				$stderr =~ s/\n/ /g;
				$stderr =~ s/\s+$//;
				$stderr =~ s/\s+/ /g;
				$main::irc->yield(privmsg => $chan => "$nick: stdout: $stdout") if defined $stdout and $stdout ne "";
				$main::irc->yield(privmsg => $chan => "$nick: \x0304stderr\x0f: \x0304$stderr") if defined $stderr and $stderr ne "";
				if ($@) {
					#$main::irc->yield(privmsg => $chan => "\x0304red, correct?");
					my $j = $@;
					$j =~ s/\n/ /g;
					$j =~ s/\s+$//;
					chomp $j;
					$main::irc->yield(privmsg => $chan => "$nick:\x0304 error: '$j'");
					return;
				}
				if (not defined $text or $text eq "") {
					return "$nick: no return value";
				}
				return "$nick: '$text'";
			}
			when (/^ping/) {
				if (not $args[0]) {
					return "$nick: \x0308\x02PONG!";
				}
				else {
					return "$args[0]: \x0308\x02PONG!";
				}
			}
			when (/^slap/) {
				$main::irc->yield(ctcp => $chan => "ACTION slaps " . join(' ', @args));
			}
			when (/^unload/) {
				if ($args[0] eq "Base") {
					$main::irc->yield(notice => $nick => "Cowardly refusing to unload \x02Base\x0f.");
				}
				$main::irc->yield(notice => $nick => "Unloading \x02$args[0]\x0f...");
				delete_package("NothingBot::Plugins::" . $args[0]);
				delete $INC{"plugins/$args[0].pm"};
				if ($::module_states{"NothingBot::Plugins::$args[0]"} ne "SUCCESS") {
					$::irc->yield(notice => $nick => "Clearing all data related to \x02$args[0]\x0f...");
					delete $::module_states{"NothingBot::Plugins::$args[0]"};
				}
				else {
					push @::unloaded, "NothingBot::Plugins::$args[0]";
				}
				$main::irc->yield(notice => $nick => "Done!");
			}
			when (/^load/) {
				$::irc->yield(privmsg => $chan => "Loading \x02$args[0]\x0f...");
				if (exists $INC{"plugins/$args[0].pm"}) {
					return "$nick: \x0304$args[0].pm\x0f is already loaded";
				}
				eval "require 'plugins/$args[0].pm';";
				if ($@) {
					delete $INC{"plugins/$args[0].pm"};
					
					return "$nick: \x0304$args[0]\x0f failed to load - '\x0302$@\x0f'";
					$::module_states{"NothingBot::Plugins::$args[0]"} = "FAILED";
					$::module_errors{"NothingBot::Plugins::$args[0]"} = $@;
				}
				else {
					eval "NothingBot::Plugins::$args[0]" . "->register()";
					if ($@) {
						$::irc->yield(privmsg=>$chan=>"\x0304Bad stuff happened. See console for details.");
						print "REGISTER failed: $@\n";
						$::module_states{"NothingBot::Plugins::$args[0]"} = "FAILED";
						$::module_errors{"NothingBot::Plugins::$args[0]"} = "REGISTER failed: $@";
						return;
					}
					$::irc->yield(privmsg => $chan => "Done!");
					$::module_states{"NothingBot::Plugins::$args[0]"} = "SUCCESS";
					delete $::module_errors{"NothingBot::Plugins::$args[0]"};
					@::unloaded = grep { $_ !~ /^NothingBot::Plugins::$args[0]/ } @::unloaded;
				}


			}
			when (/^ord/) {
				print "$nick: $args[0] => ", ord($args[0]); 
				return "$nick: $args[0] => " . ord($args[0]);
			}
			when (/^chr/) {
				return "$nick: $args[0] => " . chr($args[0]);
			}
			when (/^join/) {
				$::irc->yield(join => $args[0]);
			}
			when (/^leave/) {
				$::irc->yield(part => $args[0]);
			}
			when (/^cfg/) {
				if ($args[0] eq "reload") {
					$::irc->yield(privmsg => $chan => "Reloading \x02Config\x02...");
					&::load_config();
					return "Done!";
				}
				else {
					return "config reload - reload config.";
				}
			}
			when (/^register/) {
				$::irc->yield(privmsg => $chan => "Reloading \x02$args[0]\x0f's data...");
				delete $::handlers{"NothingBot::Plugins::" . $args[0]};
				delete $::help{$args[0]};
				"NothingBot::Plugins::$args[0]"->register();
			}
			when (/^restart/) {
				$::irc->yield(quit => "brb");
				sleep 5;
				exec($^X, $0, join(' ', @ARGV));
			}
			when (/^debug/) {
				print "$_ => $INC{$_}\n" for keys %INC;
			}
			when (/^reload/) {
				print "reload requested.\n";
				$::irc->yield(privmsg => $chan => "Reloading \x02$args[0]\x02...");
				if (not exists $INC{"plugins/$args[0].pm"}) {
					return "$args[0] isn't loaded!";
				}
				#delete_package("NothingBot::Plugins::" . $args[0]);
				delete $INC{"plugins/$args[0].pm"};
				eval "require 'plugins/$args[0].pm';";
				if ($@) {
					$::irc->yield(privmsg=>$chan=>$NothingBot::Colour::RED . "Bad stuff happened. See console for details.");
					print "$@\n";
				}
				else {
					$::module_states{"NothingBot::Plugins::$args[0]"} = "SUCCESS";
					delete $::module_errors{"NothingBot::Plugins::$args[0]"};

					$::irc->yield(privmsg => $chan => "Done!");
				}
				return undef;
			}
			when (/^load/) {
				$::irc->yield(privmsg => $chan => "Loading \x02$args[0]\x02...");
				eval 'require "plugins/$args[0].pm";';
				if ($@) {
					$::irc->yield(privmsg=>$chan=>$NothingBot::Colour::RED . "Bad stuff happened. See console for details.");
					print "$@\n";
					$::module_states{"NothingBot::Plugins::$args[0]"} = "FAILED";
					$::module_errors{"NothingBot::Plugins::$args[0]"} = $@;
				}
				else {
					eval "NothingBot::Plugins::$args[0]" . "->register()";
					if ($@) {
						$::irc->yield(privmsg=>$chan=>"\x0304Bad stuff happened. See console for details.");
						print "REGISTER failed: $@\n";
						$::module_states{"NothingBot::Plugins::$args[0]"} = "FAILED";
						$::module_errors{"NothingBot::Plugins::$args[0]"} = "REGISTER failed: $@";
					}
					$::irc->yield(privmsg => $chan => "Done!");
					$::module_states{"NothingBot::Plugins::$args[0]"} = "SUCCESS";
					delete $::module_errors{"NothingBot::Plugins::$args[0]"};
				}
				return undef;
			}
			
			when (/^quit/) {
				print "===STOPPING===\n";
				$::irc->yield(quit => "BYE!");
				sleep 1;
				exit;
			}
			when (/^runwho/) {
				$::irc->yield(whois=>$nick);
			}
		}
	}
	return undef;
}

sub handle_chanmsg {
	my ($who, $where, $what) = @_;
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];
	#print "$nick ($chan): '$what'\n";
	

	if (defined $::AWAY and $what !~ /^\Q$::prefix\Ecomeback/) {
		return 1;
	}
	#my ($nick, $what, $who, $kernel, $is_chan) = @_;
	my $msg = get_response_for($nick, $what, $who, $where);
	if (defined $msg) {
		$::irc->yield(privmsg => $chan => $msg);
	}
	
	return 0;
}

1;
