package Path::Tree::Declare;

use strict;
use warnings;

use Package::Pkg;

our $BRANCH;

sub import {
    my @arguments = splice @_, 1;

    die "Missing tree" unless @arguments;
    my $tree = shift @arguments;
    die "Invalid tree ($tree)" unless blessed $tree && $tree->isa( 'Path::Tree' );

    local $BRANCH = $tree;

    my $exporter = pkg->exporter(
        dispatch => sub {
            my $rule = shift;
            my $action = shift;
            die "Missing action" unless $action;
            die "Invalid action ($action)" unless blessed $action;
            die "Invalid action ($action)" unless $action->isa( 'Path::Tree::Declare::Token' );
            my $node = ( $BRANCH || $tree->root )->branch( $rule );
            if      ( $action->kind eq 'to' ) { $node->add( $action->data ) }
            elsif   ( $action->kind eq 'chain' ) {
                local $BRANCH = $node;
                $action->data->();
            }
            else {
                die "Invalid action ($action)";
            }
        },
        to => sub (&) { Path::Tree::Declare::Token->new( kind => 'to', data => $_[0] ) },
        chain => sub (&) { Path::Tree::Declare::Token->new( kind => 'chain', data => $_[0] ) },
        run => sub (&) { ( $BRANCH || $tree->root )->add( $_[0] ) },
    );

    goto &$exporter;
}

package Path::Tree::Declare::Token;

use Any::Moose;

has kind => qw/ is ro required 1 /;
has data => qw/ is ro /;

1;
