use Test::t;

use Path::Tree::DataMap;

my ( $map, $result );

$map = Path::Tree::DataMap->new;
$map->rule( type => 'Regexp', map => sub { $_ } );

$result = $map->map( qr// );
ok( $result );
is( ref $result, 'Regexp' );

$result = $map->map( 'xyzzy' );
ok( ! $result );

$map = Path::Tree::DataMap->new;
$map->rule( type => 'Regexp' => sub { $_ } );

$result = $map->map( qr// );
ok( $result );
is( ref $result, 'Regexp' );

$result = $map->map( 'xyzzy' );
ok( ! $result );

1;
