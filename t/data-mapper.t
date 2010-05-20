use Test::t;

use Path::Tree::DataMapper;

my ( $mapper, $map );

$mapper = Path::Tree::DataMapper->new;
$mapper->rule( Regexp => sub { $_ } );

$map = $mapper->map( qr// );
ok( $map->success );
is( ref $map->result, 'Regexp' );

$map = $mapper->map( 'xyzzy' );
ok( !$map->success );

1;
