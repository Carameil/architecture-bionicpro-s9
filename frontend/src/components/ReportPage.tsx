import React, { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import authService from '../services/authService';

const ReportPage: React.FC = () => {
  const { user, logout } = useAuth();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reportData, setReportData] = useState<any>(null);

  const downloadReport = async () => {
    try {
      setLoading(true);
      setError(null);

      // Use authenticated request through bionicpro-auth
      const response = await authService.authenticatedRequest('/api/reports', {
        method: 'GET',
      });

      if (!response.ok) {
        throw new Error('Failed to fetch report');
      }

      const data = await response.json();
      setReportData(data);
      
      // TODO: Implement actual download functionality
      console.log('Report data:', data);
      
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

    return (
    <div className="min-h-screen bg-gray-100">
      {/* Navigation */}
      <nav className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold">BionicPRO Reports</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-gray-700">Welcome, {user?.name || user?.username}</span>
        <button
                onClick={logout}
                className="px-4 py-2 text-sm text-gray-700 hover:text-gray-900"
        >
                Logout
        </button>
      </div>
          </div>
        </div>
      </nav>

      {/* Main content */}
      <div className="flex flex-col items-center justify-center mt-20">
        <div className="p-8 bg-white rounded-lg shadow-md max-w-md w-full">
          <h2 className="text-2xl font-bold mb-6 text-center">Prosthetic Usage Reports</h2>
          
          <div className="mb-6 p-4 bg-gray-50 rounded">
            <h3 className="font-semibold text-gray-700 mb-2">User Information</h3>
            <p className="text-sm text-gray-600">Username: {user?.username}</p>
            <p className="text-sm text-gray-600">Email: {user?.email || 'N/A'}</p>
            <p className="text-sm text-gray-600">Roles: {user?.roles.join(', ') || 'None'}</p>
          </div>
        
        <button
          onClick={downloadReport}
          disabled={loading}
            className={`w-full px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 ${
            loading ? 'opacity-50 cursor-not-allowed' : ''
          }`}
        >
            {loading ? 'Generating Report...' : 'Download My Report'}
        </button>

        {error && (
          <div className="mt-4 p-4 bg-red-100 text-red-700 rounded">
              <p className="text-sm">{error}</p>
            </div>
          )}

          {reportData && (
            <div className="mt-4 p-4 bg-green-100 text-green-700 rounded">
              <p className="text-sm">Report generated successfully!</p>
            </div>
          )}

          <div className="mt-6 text-center text-sm text-gray-500">
            <p>Reports contain your prosthetic usage data and telemetry information.</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ReportPage;