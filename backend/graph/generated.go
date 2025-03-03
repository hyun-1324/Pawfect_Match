package graph

// This file will be automatically regenerated based on the schema, any resolver implementations
// will be copied through when generating and any unknown code will be moved to the end.

import (
	"context"
	"matchMe/graph/model"
)

// These interfaces are needed for the resolver implementations

// QueryResolver defines methods for the Query type
type QueryResolver interface {
	User(ctx context.Context, id string) (*model.User, error)
	Bio(ctx context.Context, id string) (*model.Bio, error)
	Profile(ctx context.Context, id string) (*model.Profile, error)
	Me(ctx context.Context) (*model.User, error)
	MyBio(ctx context.Context) (*model.Bio, error)
	MyProfile(ctx context.Context) (*model.Profile, error)
	Recommendations(ctx context.Context) ([]*model.User, error)
	Connections(ctx context.Context) ([]*model.User, error)
}

// MutationResolver defines methods for the Mutation type
type MutationResolver interface {
	UpdateProfile(ctx context.Context, aboutMe string) (*model.Profile, error)
	UpdateBio(ctx context.Context, preferredGender *string, preferredNeutered *bool, preferredDistance *int, preferredLocation *string) (*model.Bio, error)
	CreateConnection(ctx context.Context, userID string) (bool, error)
	RemoveConnection(ctx context.Context, userID string) (bool, error)
}

// SubscriptionResolver defines methods for the Subscription type
type SubscriptionResolver interface {
	NewMessage(ctx context.Context, userID string) (<-chan *model.Message, error)
	UserOnlineStatus(ctx context.Context, userID string) (<-chan bool, error)
}

// UserResolver defines methods for the User type
type UserResolver interface {
	Bio(ctx context.Context, obj *model.User) (*model.Bio, error)
	Profile(ctx context.Context, obj *model.User) (*model.Profile, error)
}

// BioResolver defines methods for the Bio type
type BioResolver interface {
	User(ctx context.Context, obj *model.Bio) (*model.User, error)
}

// ProfileResolver defines methods for the Profile type
type ProfileResolver interface {
	User(ctx context.Context, obj *model.Profile) (*model.User, error)
}
