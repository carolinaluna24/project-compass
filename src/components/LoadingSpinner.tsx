import "./LoadingSpinner.css";

export default function LoadingSpinner() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="win10-spinner">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="dot" style={{ animationDelay: `${i * 0.15}s` }} />
        ))}
      </div>
    </div>
  );
}
