package Path::Tree::Declare;

use strict;
use warnings;

use Any::Moose;

use Package::Pkg;

has tree => qw/ is ro required 1 /;

sub TAG (@) {
    my @arguments;
    push @arguments, name => shift;
    push @arguments, data => shift if @_;
    return Path::Tree::Declare::Tag->new( @arguments );
}

sub import {
    my @arguments = splice @_, 1;

    die "Missing tree" unless @arguments;
    my $tree = shift @arguments;
    die "Invalid tree ($tree)" unless blessed $tree && $tree->isa( 'Path::Tree' );
    my $declare = $tree->declare;

    my $exporter = pkg->exporter(
        dispatch =>     sub     { $declare->dispatch( @_ ) },
        rule =>         sub     { $declare->rule( @_ ) },
        run =>          sub (&) { $declare->run( @_ ) },
        class =>        sub     { $declare->class( @_ ) },
        arguments =>    sub     { $declare->arguments( @_ ) },
    );

    goto &$exporter;
}

{
    no strict 'refs';
    for my $name (qw/ class arguments run /) {
        *$name = sub { TAG $name => [ splice @_, 1 ] }
    }
}

sub dispatch {
    my $self = shift;
    my @arguments = @_;

    my ( %build, $ii );
    $build{class} = pkg->load_name( $self->tree, 'Node' );
    $build{arguments} = [ tree => $self->tree ];
    $ii = 0;
    for my $argument ( @arguments ) {
        if ( blessed $argument && $argument->isa( 'Path::Tree::Declare::Tag' ) ) {
            my ( $name, $data ) = $argument->head;
            if      ( $name eq 'rule' ) {
                die "Duplicate rule" if $build{rule};
                $build{rule} = 1;
                push @{ $build{arguments} }, rule => $data
            }
            elsif   ( $name eq 'class' )      { $build{class} = $data }
            elsif   ( $name eq 'arguments' )  { push @{ $build{arguments} }, @$data }
            elsif   ( $name eq 'run' )        { push @{ $build{add} }, $data }
            else                              { die "Invalid tag ($name)" }

            next; # Skip incrementing positional argument
        }
        elsif ( 0 == $ii && ! $build{rule} ) {
            $build{rule} = 1;
            my $rule = $self->rule( $argument );
            push @{ $build{arguments} }, rule => $rule;
        }
        elsif ( ref $argument eq 'CODE' ) {
            push @{ $build{add} }, $argument;
        }
        elsif ( blessed $argument && $argument->isa( 'Path::Tree::Node' ) ) {
            push @{ $build{add} }, $argument;
        }
        else {
            die "Invalid argument ($argument) @ $ii";
        }
       $ii += 1;
    }

    my $node = $build{class}->new( @{ $build{arguments} } );
    $node->add( @{ $build{add} } ) if $build{add};
    return $node;
}

sub rule {
    my $self = shift;
    my @arguments = @_;

    die "Missing arguments" unless @arguments;

    if ( 1 == @arguments ) {
        return $self->tree->parse_rule( @arguments ) unless
            blessed $arguments[0] && $arguments[0]->isa( 'Path::Tree::Declare::Tag' );
        my ( $name, $data ) = $arguments[0]->head;
        die "Invalid (singleton) rule argument ($name)" unless $name eq 'build_class';
        return $data->new();
    }

    my $moniker = shift @arguments;
    die "Invalid rule arguments (@arguments)" if @arguments % 2;
    return pkg->load_name( $self->tree, 'Rule', $moniker )->new( @arguments );
}

package Path::Tree::Declare::Tag;

use Any::Moose;

has name => qw/ is ro required 1 isa Str /;
has data => qw/ is ro lazy_build 1 predicate _empty /;
sub _build_data { [] }
sub data0 { shift->data->[0] }
sub empty {
    my $self = shift;
    return 1 if $self->_empty;
    return 0 < scalar @{ $self->data };
}
sub head {
    my $self = shift;
    my @head = ( $self->name );
    push @head, $self->data0 unless $self->empty;
    return @head;
}

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
            die "Invalid action ($action)" unless $action->isa( 'Path::Tree::Declare::Tag' );
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
        to => sub (&) { Path::Tree::Declare::Tag->new( kind => 'to', data => $_[0] ) },
        chain => sub (&) { Path::Tree::Declare::Tag->new( kind => 'chain', data => $_[0] ) },
        run => sub (&) { ( $BRANCH || $tree->root )->add( $_[0] ) },
    );

    goto &$exporter;
}

package Path::Tree::Declare::Tag;

use Any::Moose;

has kind => qw/ is ro required 1 /;
has data => qw/ is ro /;

1;
