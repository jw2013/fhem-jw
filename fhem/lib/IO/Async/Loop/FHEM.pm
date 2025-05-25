package IO::Async::Loop::FHEM 0.001;

use v5.14;
use warnings;

use constant API_VERSION => '0.49';

use base qw( IO::Async::Loop );

use Carp;

$IO::Async::Loop::LOOP = "FHEM";

sub new
{
   my $class = shift;
   my $self = $class->__new( @_ );
   return $self;
}

sub is_running
{
   my $self = shift;
   return ($main::init_done) && !($main::reread_active);
}

sub __directReadFn
{
   my $hash = shift;
   my $cb = $hash->{on_read_ready};
   no strict "refs";
   &$cb() if $cb;
   use strict "refs";
}

sub __directWriteFn
{
   my $hash = shift;
   my $cb = $hash->{on_write_ready};
   no strict "refs";
   &$cb() if $cb;
   use strict "refs";
}

sub watch_io
{
   my $self = shift;
   my %params = @_;

   my $handle = $params{handle} or croak "Expected 'handle'";
   my $fd = $handle->fileno;
   my $id = "LOOP-".int($self)."-".$fd;

   $main::selectlist{$id} = { FD => $fd }
      unless exists $main::selectlist{$id};

   my $hash = $main::selectlist{$id};
   
   if ( $params{on_read_ready} ) {
       $hash->{on_read_ready} = $params{on_read_ready};
       $hash->{directReadFn} = \&__directReadFn;
   }

   if ( $params{on_write_ready} ) {
       $hash->{on_write_ready} = $params{on_write_ready};
       $hash->{directWriteFn} = \&__directWriteFn;
   }
}

sub unwatch_io
{
   my $self = shift;
   my %params = @_;

   my $handle = $params{handle} or croak "Expected 'handle'";
   my $fd = $handle->fileno;
   my $id = "LOOP-".int($self)."-".$fd;

   return unless exists $main::selectlist{$id};

   my $hash = $main::selectlist{$id};
   
   if ( $params{on_read_ready} ) {
       delete $hash->{on_read_ready};
       delete $hash->{directReadFn};
   }

   if ( $params{on_write_ready} ) {
       delete $hash->{on_write_ready};
       delete $hash->{directWriteFn};
   }

   if ( (!exists $hash->{on_read_ready}) && (!exists $hash->{on_write_ready}) ) {
      delete $main::selectlist{$id};
   }
}


sub __internalTimerFn
{
    my $hash = shift;
    my $cb = $hash->{on_timeout};
    no strict "refs";
    &$cb() if $cb;
    use strict "refs";
}

sub watch_time
{
   my $self = shift;
   my ( %params ) = @_;

   my $now = $self->time;
   my $delay = 0;

   if( exists $params{at} ) {
      $delay = delete($params{at}) - (exists $params{now} ? delete($params{now}) : $now);
   }
   elsif( exists $params{after} ) {
      $delay = delete($params{after}) + (exists $params{now} ? delete($params{now}) - $now : 0);
   }
   else {
      croak "Expected either 'at' or 'after' keys";
   }
   $delay = 0 if $delay < 0;

   my $hash = { on_timeout => delete $params{code} };

   main::InternalTimer( $now + $delay, \&__internalTimerFn, $hash );

   return $hash;
}

sub unwatch_time
{
   my $self = shift;
   my ( $hash ) = @_;

   main::RemoveInternalTimer( $hash, \&__internalTimerFn );

   return;
}

sub __handle_deferrals {
   my $self = shift;

   my $deferrals = $self->{deferrals};
   $self->{deferrals} = [];

   foreach my $code ( @$deferrals ) {
      $code->();
   }
}

sub __queue_deferrals
{
   my $self = shift;
   return unless scalar @{$self->{deferrals}};

   main::InternalTimer( 0, \&__handle_deferrals, $self );
}

sub watch_idle
{
   my $self = shift;
   my ( %params ) = @_;

   my $id = $self->SUPER::watch_idle(%params);
    
   main::PrioQueue_add( \&__queue_deferrals, $self );
   return $id;
}

6174;
