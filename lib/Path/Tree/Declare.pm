package Path::Tree::Declare;

use strict;
use warnings;

use Any::Moose;

use Package::Pkg;

has tree => qw/ is ro required 1 /;

sub TAG (@) {
    my @arguments;
    push @arguments, name => shift;
    push @arguments, data => [ @_ ] if @_;
    my $tag = Path::Tree::Declare::Tag->new( @arguments );
#    warn $tag->head, " < @_";
    return $tag;
}

sub import {
    my @arguments = splice @_, 1;

    die "Missing tree" unless @arguments;
    my $tree = shift @arguments;
    die "Invalid tree ($tree)" unless blessed $tree && $tree->isa( 'Path::Tree' );
    my $declare = $tree->declare;

    my $exporter = pkg->exporter(
        dispatch =>     sub     { $declare->dispatch( @_ ) },
        node =>         sub     { $declare->node( @_ ) },
        rule =>         sub     { $declare->rule( @_ ) },
        run =>          sub (&) { $declare->run( @_ ) },
        class =>        sub     { $declare->class( @_ ) },
        rule_class =>   sub     { $declare->rule_class( @_ ) },
        node_class =>   sub     { $declare->node_class( @_ ) },
        arguments =>    sub     { $declare->arguments( @_ ) },
    );

    goto &$exporter;
}

{
    no strict 'refs';
    for my $name (qw/ class arguments run /) {
        *$name = sub { TAG $name => splice @_, 1 }
    }
}

sub always {
    my $self = shift;
    return $self->rule_class( 'Always' )->data0->new();
}

sub dispatch {
    my $self = shift;
    return $self->node( @_ );
}

sub node_class {
    my $self = shift;
    my $moniker = 'Node';
    $moniker = shift if @_;
    return TAG node_class => $self->tree->loader->load( $moniker );
}

sub node {
    my $self = shift;
    my @arguments = @_;

    my $build = {};
    $build->{default_class} = $self->node_class->data0;
    $build->{arguments} = [ tree => $self->tree ];

    my $ii = 0;
    for my $argument ( @arguments ) {
        if ( blessed $argument && $argument->isa( 'Path::Tree::Declare::Tag' ) ) {
            $self->node_tag_argument( $build, $argument );
        }
        else {
            $self->node_argument( $build, $ii, $argument );
            $ii += 1;
        }
    }

    return $self->node_build( $build );

}

sub node_build {
    my $self = shift;
    my $build = shift;

    my $class = $build->{class} || $build->{default_class};
    my $node = $self->tree->_build_node( $class => @{ $build->{arguments} } );
    $node->add( @{ $build->{add} } ) if $build->{add};
    return $node;
}

sub node_tag_argument {
    my $self = shift;
    my $build = shift;
    my $argument = shift;

    my ( $name, $data ) = $argument->head;
    if      ( $name eq 'rule' ) {
        die "Duplicate rule" if $build->{rule};
        $build->{rule} = 1;
        push @{ $build->{arguments} }, rule => $data
    }
    elsif   ( $name eq 'class' )      { $build->{class} = $self->node_class( $data )->data0 }
    elsif   ( $name eq 'node_class' ) { $build->{class} = $data }
    elsif   ( $name eq 'arguments' )  { push @{ $build->{arguments} }, @$data }
    elsif   ( $name eq 'run' )        { push @{ $build->{add} }, $data }
    else                              { die "Invalid tag ($name)" }
}

sub node_argument {
    my $self = shift;
    my $build = shift;
    my $ii = shift;
    my $argument = shift;

    if ( 0 == $ii && ! $build->{rule} ) {
        $build->{rule} = 1;
        my $rule = $argument;
        $rule = $self->rule( $argument ) unless blessed $rule && $rule->can( 'match' );
        push @{ $build->{arguments} }, rule => $rule;
    }
    elsif ( ref $argument eq 'CODE' ) {
        push @{ $build->{add} }, $argument;
    }
    elsif ( blessed $argument && $argument->isa( 'Path::Tree::Node' ) ) {
        push @{ $build->{add} }, $argument;
    }
    else {
        die "Invalid argument ($argument) @ $ii";
    }
}

sub rule_class {
    my $self = shift;
    die "Missing rule class" unless @_;
    my $moniker = shift;
    return TAG rule_class => $self->tree->loader->load( 'Rule', $moniker );
}

sub rule {
    my $self = shift;
    my @arguments = @_;

    die "Missing arguments" unless @arguments;
    
    if ( 1 == @arguments ) {
        return $self->tree->parse_rule( @arguments ) unless
            blessed $arguments[0] && $arguments[0]->isa( 'Path::Tree::Declare::Tag' );
        my ( $name, $data ) = $arguments[0]->head;
        my $class;
        if      ( $name eq 'class' )        { $class = $self->rule_class( $data )->data0 }
        elsif   ( $name eq 'rule_class' )   { $class = $data }
        else                                { die "Invalid tag ($name)" }
        return $self->tree->_build_rule( $class );
    }

    my $moniker = shift @arguments;
    my $class = $self->rule_class( $moniker )->data0;
    return $self->tree->_build_rule( $class => @arguments );
}

package Path::Tree::Declare::Tag;

use Any::Moose;

has name => qw/ is ro required 1 isa Str /;
has data => qw/ is ro lazy_build 1 predicate _has_data isa ArrayRef /;
sub _build_data { [] }
sub data0 { shift->data->[0] }
sub empty {
    my $self = shift;
    return 1 unless $self->_has_data;
    return scalar @{ $self->data } ? 0 : 1;
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
