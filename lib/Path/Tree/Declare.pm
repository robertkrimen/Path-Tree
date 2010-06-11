package Path::Tree::Declare;

use strict;
use warnings;

use Any::Moose;

use Package::Pkg;

has tree => qw/ is ro required 1 /;

sub TAG (@);

sub LEXICON {
    my $self = shift;
    my $declare;
    if ( @_ ) { $declare = shift }
    elsif ( ! @_ && blessed $self )    { $declare = shift }
    else                               { $declare = shift }
    die "Missing declare" unless $declare;

    return pkg->lexicon(
        dispatch =>     sub     { $declare->dispatch( @_ ) },
        node =>         sub     { $declare->node( @_ ) },
        rule =>         sub     { $declare->rule( @_ ) },
        run =>          sub (&) { $declare->run( @_ ) },
        then =>         sub (&) { $declare->then( @_ ) },
        test =>         sub (&) { $declare->test( @_ ) },
        class =>        sub     { $declare->class( @_ ) },
        rule_class =>   sub     { $declare->rule_class( @_ ) },
        node_class =>   sub     { $declare->node_class( @_ ) },
        arguments =>    sub     { $declare->arguments( @_ ) },
    );
}

sub import {
    my $class = $_[0];
    my @arguments = splice @_, 1;

    die "Missing tree" unless @arguments;
    my $tree = shift @arguments;
    die "Invalid tree ($tree)" unless blessed $tree && $tree->isa( 'Path::Tree' );
    my $declare = $tree->declare;

    my $exporter = pkg->exporter( $class->LEXICON( $declare )->export );

    goto &$exporter;
}

{
    no strict 'refs';
    for my $name (qw/ class arguments run then test /) {
        *$name = sub { TAG $name => splice @_, 1 }
    }
}

sub always {
    my $self = shift;
    return $self->rule_class( 'Always' )->data->new();
}

sub dispatch {
    my $self = shift;
    $self->tree->root->add( $self->tree->parse->parse_node_children([ @_ ]) );
}

sub node_class {
    my $self = shift;
    my $class;
    if ( @_ )   { $self->tree->loader->load( $_[0] ) }
    else        { $class = $self->tree->node_class }
    return TAG node_class => $class;
}

sub node {
    my $self = shift;
    my @arguments = @_;

    my $build = {};
    $build->{default_class} = $self->node_class->data;
    $build->{arguments} = [ tree => $self->tree ];
    $build->{rulelist} = [ ];

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
    my $node = $self->tree->_build_node( $class =>
        rule => $build->{rulelist}->[0],
        @{ $build->{arguments} }
    );
    $node->add( @{ $build->{add} } ) if $build->{add};
    return $node;
}

sub node_tag_argument {
    my $self = shift;
    my $build = shift;
    my $argument = shift;

    my ( $tag, $data ) = $argument->tag_data;
#    if      ( $name eq 'rule' ) {
#        die "Duplicate rule" if $build->{rule};
#        $build->{rule} = 1;
#        push @{ $build->{arguments} }, rule => $data
#    }
    if      ( $tag eq 'class' )      { $build->{class} = $self->node_class( $data )->data }
    elsif   ( $tag eq 'node_class' ) { $build->{class} = $data }
    elsif   ( $tag eq 'arguments' )  { push @{ $build->{arguments} }, @$data }
    elsif   ( $tag eq 'run' )        { push @{ $build->{add} }, $data }
    else                             { die "Invalid tag ($tag)" }
}

sub node_argument {
    my $self = shift;
    my ( $build, $ii, $argument ) = @_;

    # TODO If not in a sane order?
    if      ( blessed $argument && $argument->isa( 'Path::Tree::Node' ) ) {
        push @{ $build->{add} }, $argument;
    }
    elsif   ( blessed $argument && $argument->isa( 'Path::Tree::Rule' ) ) {
        push @{ $build->{rulelist} }, $argument;
    }
    elsif   ( 0 == $ii && ! $build->{rule} ) {
        $build->{rule} = 1;
        my $rule = $argument;
        $rule = $self->rule( $argument ) unless blessed $rule && $rule->can( 'match' );
        push @{ $build->{rulelist} }, $rule;
    }
    elsif   ( ref $argument eq 'CODE' ) {
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
        my ( $tag, $data ) = $arguments[0]->tag_data;
        my $class;
        if      ( $tag eq 'class' )        { $class = $self->rule_class( $data )->data }
        elsif   ( $tag eq 'rule_class' )   { $class = $data }
        else                               { die "Invalid tag ($tag)" }
        return $self->tree->_build_rule( $class );
    }

    my $moniker = shift @arguments;
    my $class = $self->rule_class( $moniker )->data;
    return $self->tree->_build_rule( $class => @arguments );
}

sub TAG (@) {
    my @arguments;
    push @arguments, tag => shift;
    push @arguments, data => ( @_ > 1 ? [ @_ ] : $_[0] );
    my $tag = Path::Tree::Declare::Tag->new( @arguments );
    return $tag;
}

package Path::Tree::Declare::Tag;

use Any::Moose;

has tag => qw/ is ro required 1 isa Str /;
sub name { $_[0]->tag }
has data => qw/ is ro predicate _has_data /;

sub tag_data {
    my $self = shift;
    my @get = ( $self->name );
    push @get, $self->data if $self->_has_data;
    return @get;
    
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
