#!/usr/bin/perl
use strict;
use warnings;
use v5.014;
use POE qw(Component::IRC::State);
use Getopt::Long;

our %config = ();
my %handlers = ();
our @modules = qw(
	Base
	Web
);
our $cfgfile="$ENV{HOME}/.nothingbot.conf";

if (not -e $cfgfile) {
	open my $out, ">", $cfgfile or die "failed to create config file - $!";
	print $out 
	"# Lines starting with '#' are ignored.\n",
	"# nickname to use in IRC\n",
	"nick=nothingbot\n",
	"# real name to use for IRC\n",
	"user=nothingbot\n",
	"# IRC server to connect to\n",
	"server=irc.example.com\n",
	"# port of this IRC server (usually 6667 for plain, 6697 for SSL)\n",
	"port=6667\n",
	"# prefix to use for commands like help\n",
	"prefix=+\n",
	"# comma-separated list of channels to use.\n",
	"channels=##example,##example2\n",
	"# IRC user mask of admin user. CHANGE THIS OR HAVE PEOPLE HAX YOUR NOTHINGBOT.\n",
	"umask=*!*@*\n";
	print STDERR "no config file. A default has been generated at $cfgfile. ",
    "You may want to edit it before going any further.\n";
	exit 2;
}
our $gnick;
our $user;
our $srvr;
our $port;
our $prefix;
our $umask="";
our @channels;
my @ownercmds = qw(join quit restart reload); # only the owner can do these.
my @opcmds = qw(leave); # only channel ops can make the bot leave a channel.
my $print_help = 0;

GetOptions(
	"config|cfg=s"  => \$cfgfile,
	"help"			=> \$print_help
);
if ($print_help != 0) {
	print "usage: $0 [--config=FILE] [--help]\n",
	"by default, config is stored in $ENV{HOME}/.nothingbot.conf\n";
	exit 3;
}

load_config();

sub add_op_cmd {
	my $cmd = shift;
	print "op => $cmd\n";
	push @opcmds, $cmd;
}
sub add_owner_cmd {
	my $cmd = shift;
	print "owner => $cmd\n";
	push @ownercmds, $cmd;
}

sub load_config {
	undef $gnick;
   	undef $user;
	undef $srvr;
	undef $port;
   	undef $prefix;
	@channels = ();
	%config = ();
	$umask = "";
	my $file;
	open $file, "<", $cfgfile or die "Failed to read config file $file: $!";
	while (<$file>) {
		chomp;
		next if /^\s*#/;
		die "invalid line at $cfgfile line $." if not m/=/; # $. = line number. perldoc -v $.
		my @parts = split('=', $_, 2);
		if ($parts[0] eq "nick") {
			$gnick = $parts[1];
		}
		elsif ($parts[0] eq "user") {
			$user = $parts[1];
		}
		elsif ($parts[0] eq "server") {
			$srvr=$parts[1];
		}
		elsif ($parts[0] eq "port") {
			$port=$parts[1];
		}
		elsif ($parts[0] eq "prefix") {
			$prefix=$parts[1];
		}
		elsif ($parts[0] eq "channels") {
			@channels=split/,/, $parts[1];
		}
		elsif ($parts[0] eq "umask") {
			if ($parts[1] =~ /^\*!\*\@\*/) {
				print STDERR "$parts[1] is an invalid umask - too open. can't have people haxing your computer now, can we?\n";
				exit 5;
			}
			$umask = $parts[1];
			$umask =~ s/\*/\.\*/g;
		}
		$config{$parts[0]} = $parts[1];

	}
	close $file;
}

my @help = ();#("NothingBot \x02v0.1\x02");
sub register_listener_hash {
	my $hash = shift;
	for (keys %$hash) {
		if (defined $handlers{$_}) {
			my $t;
			foreach $t (@{$hash->{$_}}) {
				push @{$handlers{$_}}, $t;
			}	
		}
		else {
			$handlers{$_} = $hash->{$_};
		}
	}

	print "\nREF: ",  ref $handlers{irc_msg}, " - $handlers{irc_msg}\n";
}

sub register_help_msgs {
	#my $source = shift;
	#push @help, "\x02Commands from module $source\x02:";
	for (@_) {
		push @help, $_;
	}

}
push @INC, "./plugins";
for (@modules) {
	require "plugins/$_.pm";
	print "NothingBot::Plugins::${_}::register()";
	"NothingBot::Plugins::${_}"->register();
}


our $irc = POE::Component::IRC::State->spawn(
	nick => $gnick,
	server => $srvr,
	port => int $port,
	ircname => $user,
	username=>"uid2"
	
) or die "Failed to connect: $!";

POE::Session->create(
	package_states => [
		main => [ qw(_default _start irc_001 irc_public irc_msg irc_whois) ],
	],
	heap => { irc => $irc }
);

$poe_kernel->run();

my @memory = ();

my %lastmessages = ();


our $AWAY = undef;

sub _start {
	my ($kernel, $heap) = @_[KERNEL, HEAP];

	my $irc_session = $heap->{irc}->session_id();
	$kernel->post($irc_session => register => 'all');
	$kernel->post($irc_session => connect => {} );
	return;
}

sub _default {
	my ($event, $args) = @_[ARG0 .. $#_];
	if ($event eq "irc_372") {
		return;
	}
	my @output = ( "$event: ");
	for my $arg (@$args) {
		if (ref $arg eq 'ARRAY') {
			push(@output, "\n\t[" . join(', ', @$arg) . ']');
		}
		else {
			push @output, $arg;
		}
	}
	print join(' ', @output), "\n";
	return 0;
}

sub irc_001 {
	my ($kernel, $sender) = @_[KERNEL, SENDER];
	my $poco = $sender->get_heap(); #POE::Component object
	print "Connected to ", $poco->server_name(), "\n";
	$kernel->post( $sender => join => $_ ) for @channels;
	return;
}

sub irc_msg {
	irc_public(@_);
}

sub should_handle_msg {
	return 1;
}

sub check_can_run {
	my $cmd = shift;
	my $who = shift;
	my $where = shift;
	my $poco_obj = shift;
	my @biglist = @opcmds;
	push @opcmds, $_ for @ownercmds;
	print "check auth: $cmd for $who in $where\n";
	if ($who =~ /^$umask$/) {
		print "$who =~ /^$umask$/\n";
		return 1;
	}
	elsif (scalar(grep !/^$cmd$/, @biglist) == $#biglist) {
		print "$cmd not in biglist\n";
		return 1;
	}
	elsif (grep /^$cmd$/, @opcmds) {
		if ($poco_obj->is_channel_operator($where, (split(/!/, $who))[0])) {
			print "$cmd is op cmd and $who is op.\n";
			return 1;
		}
		else {
			print "ACCESS DENIED - op required for $who\n";
			return 0;
		}
	}
	print "allowed by default.\n";
	return 1;
}

sub irc_public {
	my ($kernel, $sender, $who, $where, $what) = @_[KERNEL, SENDER, ARG0..ARG2];
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];
	my $poco = $sender->get_heap();
	print "$who ($chan): '$what'\n";

	if ($what =~ /^\Q${prefix}\Ehelp/i or $what =~ /^${gnick}.? help/) {
		my @args = split/ /, $what;
		shift @args;
		if (@args) {
			$kernel->post($sender => privmsg => $nick => "Match(es): " . join(", ", grep(/^\Q$args[0]\E/, @help)));
		}
		else {
			my $str = "";
			for (@help) {
				$str .= (split/ /)[0] . " ";
			}
			$kernel->post($sender => privmsg => $nick => "$str");
		   	$kernel->post($sender => privmsg => $nick => "help <cmd> for more info on a command. You can also tell me".
			   " things in the format '$gnick, x is y, ok?', and ask for it back in the format '$gnick, what is x?'");
		}
		#for (@help) {
		#	$kernel->post($sender => privmsg => $nick => $_);
		#}
		#$kernel
		return;
	}
	elsif ($what =~ /^\Q${prefix}\Eauthlevel/i) {
		if ($who =~ /$umask/) {
			$kernel->post($sender => privmsg => $nick => "You are my master.");
		}
		else {
			$kernel->post($sender => privmsg => $nick => "You are just another person.");
		}
		return;
	}

	for my $handler (@{$handlers{irc_msg}}) {
		#print "pass message on to $handler.\n";
		if ($handler->($kernel, $sender, $who, $where, $what) == 1) {
			last; # they want us to stop!
		}
	}

}

sub irc_whois {
	print "whois!\n";
	my $hash = $_[ARG0];
	print ref $hash, "\n";
	print "data:\n";
	for (keys $hash) {
		if ($_ ne "channels") {
			print "$_: $hash->{$_}\n";
		}
		else {
			print "$_: ", join(', ', @{$hash->{$_}}), "\n";
		}
	}
}
