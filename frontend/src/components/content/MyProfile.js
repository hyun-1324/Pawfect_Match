import { Link } from "react-router-dom";
import useFetch from "../../tools/useFetch";

const MyProfile = () => {
  const {
    data: user,
    isPending: isPending1,
    error: error1,
  } = useFetch("http://localhost:3000/me");
  const {
    data: userProfile,
    isPending: isPending2,
    error: error2,
  } = useFetch("http://localhost:3000/me/profile");
  const {
    data: userBio,
    isPending: isPending3,
    error: error3,
  } = useFetch("http://localhost:3000/me/bio");

  if (isPending1 || isPending2 || isPending3) {
    return <div>Loading...</div>;
  }

  if (error1 || error2 || error3) {
    return <div className="errorBox">Error: {error1.message || error2.message || error3.message}</div>;
  }

  if (!user || !userProfile || !userBio) {
    return <div className="card centered">Loading data...</div>;
  }

  return (
    <div className="profile-container">
      <div className="profile-header">
        <h2>{user.dog_name}</h2>
      </div>
      <img
        src={
          user.picture
            ? user.picture
            : `${process.env.PUBLIC_URL}/images/defaultProfile.png`
        }
        alt="Dog"
      />
      <h3>About me and my owner</h3>
      <p>{userProfile.about_me}</p>
      <h3>Bio</h3>
      <p>Gender: {userBio.gender}</p>
      <p>Neutered: {userBio.neutered ? "Yes" : "No"}</p>
      <p>Size: {userBio.size} kg</p>
      <p>Energy level: {userBio.energy_level}</p>
      <p>Favorite play style: {userBio.play_style}</p>
      <p>Age: {userBio.age}</p>

      <h3>Preferences</h3>
      <p>Preferred gender: {userBio.preferred_gender}</p>
      <p>Preferred Neutered: {userBio.preferred_neutered ? "Yes" : "No"}</p>
      <p>Preferred location: {userBio.preferred_location}</p>
      <p>Preferred Distance: {userBio.preferred_distance}</p>

      <Link to="/edit/profile" className="edit-button">
        <img
          className="button navButton"
          src={`${process.env.PUBLIC_URL}/images/edit.png`}
          alt="Edit Profile"
        />
      </Link>
    </div>
  );
};
export default MyProfile;
