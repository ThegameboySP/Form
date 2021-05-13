## Conventions
All components should inherit from BaseComponent. It eases the gap between Composite and Roblox instances considerably.
```lua
local BaseComponent = require(my.path.to.BaseComponent)
local MyComponent = BaseComponent:extend("MyComponent")
```

BaseComponent:extend creates the .new constructor for you, so it shouldn't be present in derived components. All initialization that normally takes place within the constructor should be moved to :PreInit.
### Lifecycle methods:
Each lifecycle method is technically optional, as BaseComponent fills them out for you. Here is the intended order and use of the lifecycle methods:
```lua
-- Register remote events, normal events, and normal constructor initialization.
function MyComponent:PreInit()

end


-- Initialize configuration and state. Instance mutation should be done by this point.
function MyComponent:Init()

end


-- Set whatever internal processes you need into motion. Free to access other components now.
function MyComponent:Main()

end
```
### Interfaces:
Composite uses the t library to define various interfaces for a component. Each interface is optional but highly recommended.
```lua
function MyComponent.getInterfaces(t)
	return {
		-- Describes what shape you need your configuration to take.
		-- use t.strictInterface to ensure no extra configuration values other than what you've specified, or t.interface to turn off this protection.
		IConfiguration = t.strictInterface({
			Mandatory = t.number;
			Optional = t.optional(t.number);
		});

		-- Describes what you expect an instance that uses this component to look like.
		IInstance = t.instanceIsA("Model", {
			Part = t.instanceIsA("BasePart");
		});

		-- Describes what shape you need your state to take.
		IState = t.strictInterface({
			MyPublicEnum = t.valueOf({"Option1", "Option2", "Option3"});
			myProtectedValue = t.number;
			_myPrivateValue = t.string;
		})
	}
end
```

To share interfaces between the server and client without any code duplication, try this pattern from my own CTF system (all three files are under their own folder): 
```lua
-- Shared.lua
return {
	getInterfaces = function(t)
		return {
			-- You can also safely use the curly brace syntactic sugar here: choose which style you like best.
			IConfiguration = t.strictInterface {
				DespawnTime = t.number;
			};
			
			IInstance = t.instanceIsA( 'BasePart' );
			
			IState = t.strictInterface {
				State = t.valueOf { 'Docked', 'Dropped', 'Carrying' };
				equippingPlayer = t.union( t.literal(false), t.instanceIsA('Player') );
				timeLeft = t.number;
			}
		}
	end;
}
```

```lua
-- S_Flag.lua
local S_Flag = BaseComponent:extend("S_Flag")
local Shared = BaseComponent.bindToModule(script.Parent.C_Flag, script.Parent.Shared) -- Simply parents the module to C_Flag and returns it require'd
S_Flag.getInterfaces = Shared.getInterfaces
```


```lua
-- C_Flag.lua
local C_Flag = BaseComponent:extend("C_Flag")
local Shared = BaseComponent.getBoundModule(script, "Shared") -- gets require'd Shared, whether S_Flag or this was called first
C_Flag.getInterfaces = Shared.getInterfaces
```
### Style guide:
Components should use PascalCase for methods and member values that are public (including lifecycle methods), camelCase for protected methods and member values (only accessible through associated classes, such as client or sub classes, though conventional inheritance is not recommended), and _camelCase for private methods and member values. State follows the same pattern.
Configuration values should always use PascalCase.

```lua
-- from Shared.lua:
function S_Flag.getInterfaces(t)
	return {
		IConfiguration = t.strictInterface {
			DespawnTime = t.number;
		};
		
		IInstance = t.instanceIsA( 'BasePart' );
		
		IState = t.strictInterface {
			State = t.valueOf { 'Docked', 'Dropped', 'Carrying' };
			equippingPlayer = t.union( t.literal(false), t.instanceIsA('Player') );
			timeLeft = t.number;
		}
	}
end

function S_Flag:Init()
	self:SetState({
		-- The state the flag is currently in.
		State = "Docked"; -- public
		-- The time left when dropped until it returns to a flag stand.
		timeLeft = 5; -- protected
	})
end


function S_Flag:Main()
	...
end


function S_Flag:protectedMethod()
	...
end


function S_Flag:_dropped()
	...
end


function S_Flag:_docked()
	...
end


function S_Flag:_carrying()
	...
end
```

It's highly recommended to only modify another component's public state if you need to, as it can violate encapsulation. However, reading public state is much safer than modifying it. In general, only modify another component's public state if it's one very obvious value, such as ```DamageComponent.Damage```.

Components should reflect the NetworkMode through their names. Server components become S_ComponentName; client components become C_ComponentName; shared components become ComponentName. Composite looks for this convention when registering components, so be sure to use it.


## Dynamic components
#TODO

Only one component of a type can be applied to an instance. Normally this is a good thing; multiple components of the same type would very likely step over each others' toes, on top of being rather confusing. However, this can cause problems if you use Composite incorrectly. For instance, you never want to find yourself in this situation:
```lua
self.man:AddComponent(part, "Damage", {
  Damage = 15;
})
```

...unless you're sure the component doesn't already exist. Instead, it's better to make this component untracked, being added regardless of whether there is already a damage behavior attached:
```lua
self.maid:GiveTask(self.man:NewUntrackedComponent(part, "Damage", {Damage = 15}))
```

For this reason, if you must create new behavior even if it already exists, it's best to use :NewUntrackedComponent, not :AddComponent. The main tradeoff of this is that it cannot invoke any manager methods on itself, nor can it communicate with other components outside of the one that created it, since the manager does not know about it. Components must be designed to handle this. Simple "trait" components are the best candidates for this treatment.

On the other hand, if you wanted to override damage behavior from another component, you could simply use :AddComponentOrState. Let's see how we could do that.
```lua
function S_Damage:Main()
	self:bind(self.instance.Touched, function(part)
		local character = self.util.getCharacter(part)
		if not character then return end

		character.Humanoid:TakeDamage(self.state.Damage)
	end)
end
```

```lua
function Component:Main()
	local part = self.instance
	self.man:AddComponentOrState(part, "Damage", {Damage = 15})

	-- Which is the same as...
	if self.man:HasComponent(part, "Damage") then
		self.man:SetState(part, "Damage", {Damage = 15})
	else
		self.man:AddComponent(part, "Damage", {
			Damage = 15;
		})
	end
end
```

This pattern is concise and powerful. If you want your component to apply damage, no questions asked, use ```:NewUntrackedComponent```. If you want your component to potentially be overridden or modified, use ```:AddComponent```. 


## Network handling
The server is assumed to be authoritative, as it uses Roblox's built-in instance replication. Server components can communicate through state and remotes to their corresponding client components. Client components communicate only through remotes to their corresponding server components. Remotes are atomic: the component simply creates RemoteEvents and RemoteFunctions underneath their instance. Since Composite relies on Roblox's built-in replication, you can easily leverage Roblox's powerful replication system on top of state and remotes.

It's important to realize how vital state is to the client. Unlike the server, players can join at any moment, and they need to immediately synchronize their client components to the server's state. Be sure to accomodate this edge case into your components' design by fully utilizing replicated state.


## Scoped vs non-scoped managers
#TODO

To do anything in Composite, you must first instance a ComponentsManager. This handles inter-component communication (events, invoking methods, etc) and a variety of component modes. Each manager is by design non-global. You can point it at top-level trees of instances to get all components underneath, or add components manually. This way, we can add multiple managers that take care of different responsibilities in your game. For instance, one manager may be responsible for all components underneath a map; Composite is quite good at this pattern. Another manager may be responsible for all components outside of the map. The possibilities are endless.

However, there are going to be cases where your managers throughout the game need to communicate. This is where ManagerCollection comes into play. ManagerCollection links up multiple Composite managers together so they can inter-communicate. Let's see how to do that.
```lua
local man = ComponentsManager.new()
local man2 = ComponentsManager.new()
local collection = ManagerCollection.new() -- It's recommended to create only one ManagerCollection per game
collection:AddManagers(man, man2)
```

From here, the collection will receive and fire events from all added managers:
```lua
collection:ConnectEvent(instance, "SomeComponent", "Event", print)
collection:FireEvent(instance, "SomeComponent", "Event", "Hello world!") -- output: Hello world!
```

And will grant the ability to get the components of all added managers:
```lua
print(collection:GetComponent(instance, "SomeComponent") ~= nil) --> true
```

There's a bit of a footnote here, though. If there are multiple managers who provide the same component to the same instance, only the authoritative (i.e. first non-synchronized) one will be returned.

You could expose it through a modulescript, another object, or _G if you're feeling rebellious.