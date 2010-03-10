package Path::Walker::SlashDispatcher;

use strict;
use warnings;

use Any::Moose;

use Path::Walker;
use Path::Walker::Dispatcher;

has dispatcher => qw/ is ro lazy_build 1 /;
sub _build_dispatcher {
    return Path::Walker::Dispatcher->new( class_base => __PACKAGE__ );
}

sub dispatch {
    my $self = shift;
    my $query = shift;

}

1;
