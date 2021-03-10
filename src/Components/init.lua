return {
	S_ComponentsService = require(script:WaitForChild("User"):WaitForChild("S_ComponentsService"));
	C_ComponentsService = require(script:WaitForChild("User"):WaitForChild("C_ComponentsService"));

	UserUtils = require(script:WaitForChild("User"):WaitForChild("UserUtils"));
	FuncUtils = require(script:WaitForChild("User"):WaitForChild("FuncUtils"));

	BaseComponent = require(script:WaitForChild("User"):WaitForChild("BaseComponent"));
	BouncyComponent = require(script:WaitForChild("User"):WaitForChild("BouncyComponent"));
	DamageComponent = require(script:WaitForChild("User"):WaitForChild("DamageComponent"));
	ReferenceComponent = require(script:WaitForChild("User"):WaitForChild("ReferenceComponent"));

	Event = require(script:WaitForChild("Modules"):WaitForChild("Event"));
	Maid = require(script:WaitForChild("Modules"):WaitForChild("Maid"));
	t = require(script:WaitForChild("Modules"):WaitForChild("t"));
}