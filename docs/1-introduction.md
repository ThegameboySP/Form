## Motivation
In Roblox, there is no official way to make our own objects a part of the DataModel. Instead, we have to make due with manipulating built-in objects from some script. This inherently lends itself to components: that is, independent processes acting on an object.

Roblox suggests using CollectionService for this — a singleton service that allows you to tag instances into groups. The pattern goes something like this:
```lua
-- Inside some server script...

local CollectionService = game:GetService("CollectionService")

local MY_TAG = "Damage"

local function onTagAdded(instance)
	-- make instance hurt a character on touch
end

CollectionService:GetInstanceAddedSignal(MY_TAG):Connect(onTagAdded)
for _, instance in next, CollectionService:GetTagged(MY_TAG) do
	onTagAdded(instance)
end
```

But it's not without its flaws. For one, we have the issue of ambigious initialization times. A component can be added at any time without respect for when any other components initialize. This makes communication inherently asynchronous (a component may have to wait for other components to initialize), which is not good, especially for when you want to initialize all components in a map simultaneously.

Another issue is that it completely relies on Roblox's DataModel for communication between components, which is limited: It's well known that BindableEvents deeply copy tables, stripping them of their metatables and identity; bindables are unwieldy to handle at scale; and you have to wait for them to eventually spawn, probably with :WaitForChild.

Yet another issue is that it's also unwieldy to have server and client components communicating with each other with just CollectionService holding it together.

Clearly, it would be nice if there were some framework that allows us to easily and robustly add our own components to Roblox instances. It would solve all of these problems and more with helpful abstractions.

This is where Composite comes into play.

## Why Composite?
Composite handles all of the previously stated issues and more. Its big use case is for adding components in bursts, giving guarantees to components about when the rest of the components are initialized, and allowing you to easily replace modified instances afterwards. But it's useful for much more than that. Here are some of its other use cases:

- Add or remove components to any instances, any time.
- Easily bridge server and client components, even allowing players joining mid-game to synchronize with server components with the correct state.
- Allows you to re-initialize instances after modifying them. For example, a part that has a component attached that makes it explode on touch and destroy all its joints, but after the map is reloaded, it resets the instance back to its un-exploded state.
- Compose behavior on top of non-Composite instances. This behavior can easily be removed later without harming the original instance.

On a higher level, Composite allows you to start thinking about scripting in more object-oriented ways. If you like, you could only apply one component per instance, aligning itself more with what is common in object-oriented frameworks.

## Getting started

Composite tries to be as light-weight as possible. That means it tries to keep assumptions about what you're using these components for to a minimum. It also means that you need to write code to let Composite know what it should and should not do with your game.

Before we write any code, you need to understand how Composite works. Composite will always produce an initial copy of an instance you want to give a component to. How this works on an instance is determined by the instance's ComponentMode option:

- Respawn: This will destroy the instance after all components are removed from it, then use the internal clone to reproduce the instance later with the same components. This is useful for maps, where if you reload the map all instances with components will be reset.

- NoRespawn: Once all components are removed, the instance is destroyed forever. However, it may be reset with its internal clone before that happens. TODO

- Overlay: Once all components are removed, the instance is preserved. Most useful for non-Composite instances you want to assign behavior to. *It still makes an internal clone*, though this may change later.

Each of these options are useful for different use cases. Additionally, there are two basic ways to add a component to an instance:

- :Init(instance) followed by :RunAndMerge() : :Init(instance) picks up all components under the provided instance, perhaps in Studio using the popular Tag Editor plugin. It clones all instances with at least 1 component, then promptly parents those instances to nil for safekeeping. :RunAndMerge() will run all components under a certan filter Composite knows about if they haven't been run yet. **If a component is added this way, they will automatically get ComponentMode.Respawn**.

- :AddComponent() : Adding components this way allows us to explicitly set the .ComponentMode for the instance, if it did not previously have a component.

Now that that's out of the way, we can finally get down to writing some code.

Assume we have a simple service on hand called MapService. It exposes a signal that fires every time the map changes. Our job is to make Composite search for and activate components under the new map when that happens. 

This is what that could look like:
```lua
local manager = ComponentsManager.new()
local function onMapChanged(map)
	manager:Stop()
	manager:Init(map)
	manager:RunAndMergeGroups({
		Default = true
	})
end

MapService.MapChanged:Connect(onMapChanged)
if MapService.CurrentMap then
	onMapChanged(MapService.CurrentMap)
end
```

Let's decompose this line by line.

```lua
-- We instance a manager. Managers are the basic unit of component execution in Composite.
local manager = ComponentsManager.new()
local function onMapChanged(map)
	-- Releases the manager's tracked instances and components, if it had any.
	manager:Stop()

	-- This picks up all components we've added to the map, perhaps in Studio using the popular Tag Editor plugin.
	-- Each instance that has a component is cloned and deparented for now.
	manager:Init(map)

	-- Every instance with a component has a "group". Like CollectionService, an instance can be in multiple groups.
	-- Every component we picked up with :Init that had no manual grouping is run in a batch.
	manager:RunAndMergeGroups({
		Default = true
	})
end

-- Connect to .MapChanged.
MapService.MapChanged:Connect(onMapChanged)

-- If we were late and MapService already has a map, process it!
if MapService.CurrentMap then
	onMapChanged(MapService.CurrentMap)
end
```

Phew! As you can see, all we have to do is point the manager in the right direction and it will just do the rest. However, there are a few things manager cannot do. It can't bridge the server-client model by itself, for instance. For that, we need to have services for Composite on the server and client, globally accessible objects that are in charge of networking amongst other things.

Thankfully, they come out of the box. You can do whatever you like with them: remix them, wrap them with your own services, or use them as suggestions and make your own.