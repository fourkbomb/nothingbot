#!/usr/bin/perl
use strict;
use warnings;
use v5.010;
use POE qw(Component::IRC::State);


my %handlers = ();
my @modules = qw(
	Base
);
our $gnick="forkbot";
our $user="bot(){ bot|bot&; }; bot - NOT RUNNING AS ROOT.";
our $srvr="irc.freenode.net";
our $port=6667;
our $prefix='&';
our @channels = qw(##ninjabottest); ##ncss_challenge);

my @help = ("NothingBot \x02v0.1\x02");
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
	my $source = shift;
	push @help, "\x02Commands from module $source\x02:";
	for (@_) {
		push @help, $_;
	}

}
push @INC, ".";
for (@modules) {
	require "plugins/$_.pm";
	print "NothingBot::Plugins::${_}::register()";
	"NothingBot::Plugins::${_}"->register();
}


our $irc = POE::Component::IRC::State->spawn(
	nick => $gnick,
	server => $srvr,
	port => $port,
	ircname => $user,
	username=>"uid2"
	
) or die "Failed to connect: $!";

POE::Session->create(
	package_states => [
		main => [ qw(_default _start irc_001 irc_public irc_msg) ],
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
	my @output = ( "$event: ");
	for my $arg (@$args) {
		if (ref $arg eq 'ARRAY') {
			push(@output, '[' . join(', ', @$arg) . ']');
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

sub irc_public {
	my ($kernel, $sender, $who, $where, $what) = @_[KERNEL, SENDER, ARG0..ARG2];
	my $nick = (split/!/, $who)[0];
	my $chan = $where->[0];
	my $poco = $sender->get_heap();
	print "$nick ($chan): '$what'\n";
	if (should_handle_msg() == 0 and $what !~ /^\Q${prefix}\Ecomeback/) {
		return;
	}

	if ($what =~ /^\Q${prefix}\Ehelp/i or $what =~ /^${gnick}.? help/) {
		for (@help) {
			$kernel->post($sender => privmsg => $who => $_);
		}
		return;
	}

	for my $handler (@{$handlers{irc_msg}}) {
		print "pass message on to $handler.\n";
		if ($handler->($kernel, $sender, $who, $where, $what) == 1) {
			last; # they want us to stop!
		}
	}

}
