package Path::Tree::Node;

use Any::Moose;

has tree => qw/ is ro /;
has rule => qw/ is ro required 1 /;
has children => qw/ accessor _children isa ArrayRef /, default => sub { [] };
sub children { return @{ shift->_children } }
#has [qw/ before after end /] => qw/ is rw isa Maybe[CodeRef] /;

sub add {
    my $self = shift;
    push @{ $self->_children }, @_;
}

sub dispatch {
    my $self = shift;
    my $dispatch = shift;

    return unless $dispatch->consume( $self );

    for my $child ( $self->children ) {
        if ( blessed $child && $child->isa(qw/ Path::Tree::Node /) ) {
            # TODO && $child->does( 'Route' )
            last if $child->dispatch( $dispatch );
        }
        else {
            $dispatch->visit( $child );
        }
    }

    return 1;
}

sub match {
    my $self = shift;
    return unless my $match = $self->rule->match( @_ );
    $self->matched( $match );
    return $match;
}

sub matched {
}

sub branch {
    my $self = shift;
    my $node = $self->tree->node( @_ );
    $self->add( $node );
    return $node;
}

1;
