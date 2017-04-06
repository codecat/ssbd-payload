namespace WorldScript
{
	[WorldScript color="200 200 100" icon="system/icons.png;416;128;32;32"]
	class PayloadTeamForcefield
	{
		[Editable]
		bool Attackers;

		[Editable validation=IsCollider colliders=true]
		UnitFeed Units;

		void Initialize()
		{
			g_teamForceFields.insertLast(this);
		}
	}
}
