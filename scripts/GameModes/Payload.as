[GameMode]
class Payload : TeamVersusGameMode
{
	[Editable]
	UnitFeed PayloadUnit;

	[Editable]
	UnitFeed FirstNode;

	Payload(Scene@ scene)
	{
		super(scene);
	}
}
