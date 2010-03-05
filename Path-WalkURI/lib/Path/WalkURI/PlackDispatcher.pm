package Path::WalkURI::PlackDispatcher;

use strict;
use warnings;

use Any::Moose;

use Path::WalkURI::Dispatcher;

has dispatcher => qw/ is ro lazy_build 1 /, handles => [qw/ route /];
sub _build_dispatcher {
    my $self = shift;
    return Path::WalkURI::Dispatcher->new;
}

sub dispatch {
    my $self = shift;
    my $path = shift;

#    $self->dispatcher->dispatch( $path, walker => [ with_walker => sub {
#        my %given = @_;
#        my $context = Path::WalkURI::PlackDispatcher::Context->new( walker => $given{walker} );
#        $context->walker->visitor( sub {
#            my $data = $_[1];
#            if ( ref $data eq 'CODE' ) {
#                $data->( $context );
#            }
#            else {
#                die "Do not know how to visit data ($data)";
#            }
#        
#        } );
#        return $context->walker;
#    } ] );
    $self->dispatcher->dispatch( $path, prepare_walker => sub {
        my $walker = shift;
        my $context = Path::WalkURI::PlackDispatcher::Context->new( walker => $walker );
        $walker->visitor( sub {
            my $data = $_[1];
            if ( ref $data eq 'CODE' ) {
                $data->( $context );
            }
            else {
                die "Do not know how to visit data ($data)";
            }
        
        } );
    } );
}

package Path::WalkURI::PlackDispatcher::Context;

use Any::Moose;

has walker => qw/ is ro required 1 /, handles => [qw/ step /];

1;
