# Shipmates

Find a nearby person who needs what you offer.

1. Open Shipmates.
2. Press SELECT to share the default ask and offer.
3. Select a nearby badge.
4. Press SELECT to say hello.
5. When both people say hello, find the matching meeting code and steady LED color.
6. Scan the public profile QR to keep in touch.

Optional: change the ask and offer before starting. UP/DOWN selects a field. LEFT/RIGHT changes its topic.
From the people list, RIGHT shows the invite QR. BACK returns to the editor. BACK again stops sharing.

Sharing starts off on every launch. The app broadcasts topics, badge ID through the mesh envelope, and the current hello target.
Other people nearby can observe them. The app does not send data to a project server.
It saves your chosen topics and up to 16 mutually selected connections on the badge.
UP from the first field opens the Connections row. SELECT opens it. LEFT in the list offers to clear saved connections.
The glow stops after 20 seconds or when sharing stops. It never flashes.
Badge IDs and public handles are not authenticated identities.

Peers expire after 15 seconds without a state message. Delivery and radio range are not guaranteed.
Both badges need the same mesh channel and this app open. The app pauses Wi-Fi when the radio requires it.
A new badge needs the platform's first Wi-Fi hello before it can identify itself on the mesh.

Permissions: `mesh` and `led`. The public handle comes from the badge's existing owner label.
No payment, wallet, or project account is required.
