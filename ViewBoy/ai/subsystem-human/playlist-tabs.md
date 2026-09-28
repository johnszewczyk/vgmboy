# Playlist Tabs

Playlist tabs belonged to the retired DOM interface. The Yoga LCD front end currently presents one browsed game's track list and a full-width Queue page. The native `PlaylistTabsStore` implementation remains in source, but the new renderer does not call it. Tab creation, switching, and saved tab restoration need a deliberate canvas interaction design before being exposed again.
