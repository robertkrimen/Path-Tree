package Path::Tree::Declare;

use strict;
use warnings;

use Any::Moose;

use Package::Pkg;

has tree => qw/ is ro required 1 /;

#our $BRANCH;

#sub import {
#    my @arguments = splice @_, 1;

#    die "Missing tree" unless @arguments;
#    my $tree = shift @arguments;
#    die "Invalid tree ($tree)" unless blessed $tree && $tree->isa( 'Path::Tree' );

#    local $BRANCH = $tree;

#    my $exporter = pkg->exporter(
#        dispatch => sub {
#            my $rule = shift;
#            my $action = shift;
#            die "Missing action" unless $action;
#            die "Invalid action ($action)" unless blessed $action;
#            die "Invalid action ($action)" unless $action->isa( 'Path::Tree::Declare::Token' );
#            my $node = ( $BRANCH || $tree->root )->branch( $rule );
#            if      ( $action->kind eq 'to' ) { $node->add( $action->data ) }
#            elsif   ( $action->kind eq 'chain' ) {
#                local $BRANCH = $node;
#                $action->data->();
#            }
#            else {
#                die "Invalid action ($action)";
#            }
#        },
#        to => sub (&) { Path::Tree::Declare::Token->new( kind => 'to', data => $_[0] ) },
#        chain => sub (&) { Path::Tree::Declare::Token->new( kind => 'chain', data => $_[0] ) },
#        run => sub (&) { ( $BRANCH || $tree->root )->add( $_[0] ) },
#    );

#    goto &$exporter;
#}

sub TOKEN (@) {
    my @arguments;
    push @arguments, name => shift;
    push @arguments, data => shift if @_;
    return Path::Tree::Declare::Token->new( @arguments );
}

sub run { TOKEN run => $_[1] }

sub resolve_dispatch {
    my $self = shift;
    my @arguments = @_;

    my ( %build, $ii );
    $build{build_class} = pkg->load_name( $self->tree, 'Node' );
    $build{build_arguments} = [ tree => $self->tree ];
    $ii = 0;
    for my $argument ( @arguments ) {
        if ( blessed $argument && $argument->isa( 'Path::Tree::Declare::Token' ) ) {
            my ( $name, $data ) = ( $argument->name, $argument->data );
            if      ( $name eq 'rule' ) {
                die "Duplicate rule" if $build{rule};
                $build{rule} = 1;
                push @{ $build{build_arguments} }, rule => $data
            }
            elsif   ( $name eq 'build_class' )      { $build{build_class} = $data }
            elsif   ( $name eq 'build_arguments' )  { push @{ $build{build_arguments} }, @$data }
            elsif   ( $name eq 'run' )              { push @{ $build{add} }, $data }
            elsif   ( $name eq 'dispatch' )         { push @{ $build{add} }, @$data }
        }
        elsif ( 0 == $ii && ! $build{rule} ) {
            $ii += 1;
            $build{rule} = 1;
            my $rule = $self->resolve_rule( $argument );
            push @{ $build{build_arguments} }, rule => $rule;
        }
        elsif ( ref $argument eq 'CODE' ) {
            $ii += 1;
            push @{ $build{add} }, $argument;
        }
        elsif ( blessed $argument && $argument->isa( 'Path::Tree::Node' ) ) {
            push @{ $build{add} }, $argument;
        }
        else {
            die "Invalid argument ($argument) @ $ii";
        }
    }

    my $node = $build{build_class}->new( @{ $build{build_arguments} } );
    $node->add( @{ $build{add} } ) if $build{add};
    return $node;
}

sub resolve_rule {
    my $self = shift;
    my @arguments = @_;

    die "Missing arguments" unless @arguments;

    if ( 1 == @arguments ) {
        return $self->tree->parse_rule( @arguments ) unless
            blessed $arguments[0] && $arguments[0]->isa( 'Path::Tree::Declare::Token' );
        my ( $name, $data ) = ( $arguments[0]->name, $arguments[0]->data );
        die "Invalid (singleton) rule argument ($name)" unless $name eq 'build_class';
        return $data->new();
    }

    my $moniker = shift @arguments;
    die "Invalid rule arguments (@arguments)" if @arguments % 2;
    return pkg->load_name( $self->tree, 'Rule', $moniker )->new( @arguments );
}

package Path::Tree::Declare::Token;

use Any::Moose;

has name => qw/ is ro required 1 isa Str /;
has data => qw/ is ro /;

1;

__END__

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
