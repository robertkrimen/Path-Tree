package Path::Tree::Dispatch;

use Any::Moose;

use Try::Tiny;

has path => qw/ is rw required 1 isa Str /;

has _visited => qw/ is ro isa ArrayRef /, default => sub { [] };
sub visited {
    my $self = shift;
    return @{ $self->_visited } unless @_;
    my $ii = shift;
    $ii = -1 unless defined $ii;
    return $self->_visited->[ $ii ];
}

sub head {
    my $self = shift;
    return $self->_visited->[ 0 ];
}

sub tail {
    my $self = shift;
    return $self->_visited->[ -1 ];
}

sub consume {
    my $self = shift;
    my $node = shift;

    my ( $path, $visit, $lvisit, $lprefix, $lsegment );
    if ( $lvisit = $self->tail ) {
        $path = $lvisit->leftover;
        $lprefix = $lvisit->prefix;
        $lsegment = $lvisit->segment;
    }
    else {
        $path = $self->path;
        $lprefix = $lsegment = '';
    }
    my $rule = $node->rule;
    
    return 0 unless my $match = $rule->match( $path );

    {
        my $leftover = $match->{leftover};
        my $segment = substr $path, 0, -1 * length $leftover;
        my $prefix = join '', $lprefix, $lsegment;

        $visit = $self->push(
            match => $match,
            segment => $segment,
            prefix => $prefix,
            leftover => $leftover,
            node => $node,
        );
    }

    return 1;
}

sub push {
    my $self = shift;
    my $visit = $self->_visit( @_ );
    push @{ $self->_visited }, $visit;
    return $visit;
}

sub _visit {
    my $self = shift;
    return Path::Tree::DispatchVisit->new( @_ );
}

sub pop {
    my $self = shift;
    pop @{ $self->_visited };
    # TODO Cannot pop off the last (first) one
}

sub visit {
    my $self = shift;
}

package Path::Tree::DispatchVisit;

use Any::Moose;

has node => qw/ is ro required 1 /;
has [qw/ prefix leftover segment /] => qw/ is ro isa Str /, default => '';
has captured => qw/ is ro isa ArrayRef /, default => sub { [] };

1;

1;

__END__

has dispatcher => qw/ is ro required 1 /;

has path => qw/ accessor initial_path required 1 isa Str /;

has visited => qw/ is ro isa ArrayRef /, default => sub { [] };

has visitor => qw/ is rw isa CodeRef /;

sub BUILD {
    my $self = shift;
    $self->push( route => $self->root, leftover => $self->initial_path );
}

sub walk {
    my $self = shift;
    $self->walk_route( $self->root );
}

sub walk_route {
    my $self = shift;
    my $route = shift;

    $self->visit( $route->before ) if $route->before;

    for my $child ( $route->children ) {
        if ( blessed $child && $child->isa(qw/ Path::Tree::Route /) ) {
            # TODO && $child->does( 'Route' )
            last if $self->visit_route( $child );
        }
        else {
            $self->visit( $child );
        }
    }

    $self->visit( $route->after ) if $route->after;

    $self->visit( $route->end ) if $route->end;
}

sub visit {
    my $self = shift;
    my $data = shift;

    $self->dispatcher->visit( $self->visitor, walker => $self, data => $data );
}

sub visit_route {
    my $self = shift;
    my $route = shift;

    return 0 unless $self->consume( $route ); # Does a push

    my $error;
    try { $self->walk_route( $route ) } catch { $error = $_ };
    $self->pop;
    die $error if $error;

    return 1;
}
